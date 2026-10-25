require "test_helper"

class SurveysTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  PW = "Str0ng!Pass#1".freeze

  setup do
    ActionMailer::Base.deliveries.clear
    @family = Family.create!(name: "Survey Test", slug: "survey-test")
    @org = mk("org@example.test", "organizer", "Thea")
    @mem = mk("mem@example.test", "member", "Mem")
    @kin = @family.people.create!(first_name: "Kin", last_name: "Person", email: "kin@example.test")
    @noemail = @family.people.create!(first_name: "No", last_name: "Email")
    sign_in(@org)
  end

  def mk(email, role, name)
    u = User.create!(email: email, password: PW, name: name)
    @family.memberships.create!(user: u, role: role)
  end

  def sign_in(m) = post(user_session_path, params: { user: { email: m.user.email, password: PW } })

  def create_survey(extra = {})
    post "/f/survey-test/surveys", params: { survey: { title: "Which dates?", intro: "Help us pick.", closes_on: (Date.current + 14).to_s, questions: {
      "0" => { prompt: "Which weekend?", kind: "single", options_text: "July 10\nJuly 17" },
      "1" => { prompt: "Dates that work", kind: "dates", options_text: "" },
      "2" => { prompt: "Anything else?", kind: "long", options_text: "" },
      "3" => { prompt: "", kind: "short", options_text: "" }
    } }.merge(extra) }
    Survey.order(:id).last
  end

  def send_it(survey, audience, confirm: true)
    post "/f/survey-test/surveys/#{survey.id}/send", params: { audience: audience, confirm: (confirm ? "1" : nil) }.compact
  end

  def token_from_last_mail
    mail = ActionMailer::Base.deliveries.last
    (mail.text_part&.body || mail.body).to_s[%r{/s/([\w-]+)}, 1]
  end

  test "an organizer creates a survey and blank questions are ignored" do
    s = create_survey
    assert_redirected_to "/f/survey-test/surveys/#{s.id}"
    assert_equal [ "Which weekend?", "Dates that work", "Anything else?" ], s.questions.map(&:prompt)
    assert_equal [ "July 10", "July 17" ], s.questions.first.options
    assert s.draft?
  end

  test "a choice question needs two choices and a survey needs a question" do
    post "/f/survey-test/surveys", params: { survey: { title: "Bad", questions: { "0" => { prompt: "Pick", kind: "single", options_text: "only one" } } } }
    assert_response :unprocessable_entity
    post "/f/survey-test/surveys", params: { survey: { title: "Empty", questions: { "0" => { prompt: "", kind: "short" } } } }
    assert_response :unprocessable_entity
    assert_equal 0, Survey.count
  end

  test "a plain member cannot see or create surveys" do
    s = create_survey
    delete destroy_user_session_path
    sign_in(@mem)
    get "/f/survey-test/surveys"
    assert_response :forbidden
    get "/f/survey-test/surveys/#{s.id}"
    assert_response :forbidden
    post "/f/survey-test/surveys/#{s.id}/send", params: { audience: "members", confirm: "1" }
    assert_response :forbidden
    assert_empty ActionMailer::Base.deliveries
  end

  test "preview sends nothing; confirming mails every member and listed person once, with their own link" do
    s = create_survey
    send_it(s, "everyone", confirm: false)
    assert_response :success
    assert_includes response.body, "Check before sending"
    assert_empty ActionMailer::Base.deliveries
    send_it(s, "everyone")
    to = ActionMailer::Base.deliveries.flat_map(&:to).sort
    assert_equal %w[kin@example.test mem@example.test org@example.test], to
    assert_equal "open", s.reload.status
    assert_equal 3, s.recipients.count
    raws = ActionMailer::Base.deliveries.map { |m| (m.text_part&.body || m.body).to_s[%r{/s/([\w-]+)}, 1] }
    assert_equal 3, raws.uniq.size
    raws.each { |r| assert_not SurveyRecipient.where(token_digest: r).exists?, "raw token must not be stored" }
    assert_match(/survey-test|Survey Test/, ActionMailer::Base.deliveries.last.to_s)
  end

  test "a person answers through the link, can change the answers, and bad input is ignored" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    get "/s/#{token}"
    assert_response :success
    assert_includes response.body, "Which weekend?"
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
    q1, q2, q3 = s.questions.to_a
    patch "/s/#{token}", params: { answers: { q1.id.to_s => "July 17", q2.id.to_s => { dates: [ "2027-07-10", "not a date", "2027-07-17" ], note: "no Sundays" }, q3.id.to_s => "Bring cake" } }
    assert_response :success
    resp = SurveyResponse.last
    assert_equal [ "July 17" ], resp.answers.find_by(survey_question: q1).choices
    assert_equal [ "2027-07-10", "2027-07-17" ], resp.answers.find_by(survey_question: q2).choices
    patch "/s/#{token}", params: { answers: { q1.id.to_s => "Tuesday (not an option)", q2.id.to_s => { dates: [ "2027-08-01" ] } } }
    assert_equal 1, SurveyResponse.count
    assert_nil SurveyResponse.last.answers.find_by(survey_question: q1), "a choice that is not offered is dropped"
    assert_equal [ "2027-08-01" ], SurveyResponse.last.answers.find_by(survey_question: q2).choices
  end

  test "a closed survey takes no more answers" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    post "/f/survey-test/surveys/#{s.id}/close"
    get "/s/#{token}"
    assert_includes response.body, "closed"
    patch "/s/#{token}", params: { answers: { s.questions.first.id.to_s => "July 10" } }
    assert_equal 0, SurveyResponse.count
  end

  test "an expired closing date also closes the link" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    s.update_columns(closes_on: Date.current - 1)
    get "/s/#{token}"
    assert_includes response.body, "closed"
  end

  test "reminding the unanswered sends only to them and replaces their old link" do
    s = create_survey
    send_it(s, "everyone")
    tokens = ActionMailer::Base.deliveries.map { |m| [ m.to.first, (m.text_part&.body || m.body).to_s[%r{/s/([\w-]+)}, 1] ] }.to_h
    answerer_email, answerer_token = tokens.first
    patch "/s/#{answerer_token}", params: { answers: { s.questions.first.id.to_s => "July 10" } }
    ActionMailer::Base.deliveries.clear
    send_it(s, "unanswered")
    sent_to = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_equal tokens.keys.sort - [ answerer_email ], sent_to.sort
    assert_match(/\AReminder: /, ActionMailer::Base.deliveries.first.subject)
    tokens.except(answerer_email).each { |_, old| assert_nil SurveyRecipient.find_by_token(old), "old link replaced" }
    assert SurveyRecipient.find_by_token(answerer_token), "the person who answered keeps their link"
  end

  test "someone who opts out is never sent a survey again" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    get "/s/#{token}/stop"
    assert_response :success
    assert_no_difference "SurveyOptOut.count" do
      get "/s/#{token}/stop"
    end
    post "/s/#{token}/stop"
    assert_equal 1, SurveyOptOut.count
    ActionMailer::Base.deliveries.clear
    s2 = create_survey
    send_it(s2, "listed")
    assert_not_includes ActionMailer::Base.deliveries.flat_map(&:to), SurveyOptOut.last.email
  end

  test "the organizers-only audience mails only organizers" do
    s = create_survey
    send_it(s, "organizers")
    assert_equal [ "org@example.test" ], ActionMailer::Base.deliveries.flat_map(&:to)
  end

  test "an invalid or other-family link is just not found" do
    get "/s/not-a-real-token-at-all-12345"
    assert_response :not_found
  end

  test "the daily cap is shared with reminder messages" do
    s = create_survey
    @family.announcements.create!(user: @org.user, audience: "everyone", body: "earlier", recipient_count: Announcement::DAILY_LIMIT - 1)
    send_it(s, "everyone")
    assert_redirected_to "/f/survey-test/surveys/#{s.id}/send/new"
    assert_empty ActionMailer::Base.deliveries
  end

  test "results show counts and names, and hide names when asked" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    patch "/s/#{token}", params: { answers: { s.questions.first.id.to_s => "July 10", s.questions.third.id.to_s => "Hello there" } }
    get "/f/survey-test/surveys/#{s.id}"
    assert_includes response.body, "Hello there"
    assert_includes response.body, "Kin Person"
    s.update!(hide_names: true)
    get "/f/survey-test/surveys/#{s.id}"
    assert_includes response.body, "Hello there"
    assert_not_includes response.body, "Kin Person"
  end

  test "suggested dates become proposed dates on a reunion, once" do
    s = create_survey
    send_it(s, "listed")
    token = token_from_last_mail
    patch "/s/#{token}", params: { answers: { s.questions.second.id.to_s => { dates: [ "2027-07-10", "2027-07-17" ] } } }
    r = @family.reunions.create!(title: "Reunion 2027")
    assert_difference "DateOption.count", 2 do
      post "/f/survey-test/surveys/#{s.id}/questions/#{s.questions.second.id}/date_options", params: { reunion_id: r.id }
    end
    assert_no_difference "DateOption.count" do
      post "/f/survey-test/surveys/#{s.id}/questions/#{s.questions.second.id}/date_options", params: { reunion_id: r.id }
    end
  end

  test "another family's organizer cannot reach this family's survey" do
    s = create_survey
    other = Family.create!(name: "Other", slug: "other")
    ou = User.create!(email: "x@example.test", password: PW, name: "X")
    other.memberships.create!(user: ou, role: "organizer")
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: ou.email, password: PW } }
    get "/f/survey-test/surveys/#{s.id}"
    assert_response :not_found
  end

  test "a sent survey keeps its questions when edited" do
    s = create_survey
    send_it(s, "listed")
    patch "/f/survey-test/surveys/#{s.id}", params: { survey: { title: "Renamed", questions: { "0" => { prompt: "Sneaky", kind: "short" } } } }
    assert_equal "Renamed", s.reload.title
    assert_equal 3, s.questions.count
  end
end
