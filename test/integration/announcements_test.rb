require "test_helper"

class AnnouncementsTest < ActionDispatch::IntegrationTest
  PW = "Str0ng!Pass#1".freeze

  setup do
    ActionMailer::Base.deliveries.clear
    @family = Family.create!(name: "Ann Test", slug: "ann-test")
    @org = mk("org@example.test", "organizer", "Thea")
    @a = mk("a@example.test", "member", "Ann")
    @b = mk("b@example.test", "member", "Bob")
    @b.update!(email_reminders: false)
  end

  def mk(email, role, name)
    u = User.create!(email: email, password: PW, name: name)
    @family.memberships.create!(user: u, role: role)
  end

  def sign_in(m) = post(user_session_path, params: { user: { email: m.user.email, password: PW } })

  def send_params(extra = {}) = { announcement: { audience: "everyone", subject: "Pot luck", body: "Bring a dish." }.merge(extra) }

  test "a plain member cannot reach it" do
    sign_in(@a)
    get "/f/ann-test/announcements/new"
    assert_response :forbidden
    post "/f/ann-test/announcements", params: send_params.merge(confirm: "1")
    assert_response :forbidden
    assert_empty ActionMailer::Base.deliveries
  end

  test "the preview shows who gets it and sends nothing" do
    sign_in(@org)
    post "/f/ann-test/announcements", params: send_params
    assert_response :success
    assert_includes response.body, "Check before sending"
    assert_includes response.body, "Ann"
    assert_not_includes response.body.split("This goes to").last.split("</p>").first, "Bob"   # opted out
    assert_empty ActionMailer::Base.deliveries
  end

  test "confirming sends to everyone who has reminders on, with an unsubscribe link, and records it" do
    sign_in(@org)
    assert_difference "Announcement.count", 1 do
      post "/f/ann-test/announcements", params: send_params.merge(confirm: "1")
    end
    to = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_equal %w[a@example.test org@example.test].sort, to.sort
    mail = ActionMailer::Base.deliveries.first
    assert_match(/unsubscribe/i, mail.header["List-Unsubscribe"].to_s)
    assert_equal 2, Announcement.last.recipient_count
  end

  test "the daily limit stops an oversized send" do
    sign_in(@org)
    @family.announcements.create!(user: @org.user, audience: "everyone", body: "earlier", recipient_count: Announcement::DAILY_LIMIT - 1)
    post "/f/ann-test/announcements", params: send_params.merge(confirm: "1")
    assert_redirected_to "/f/ann-test/announcements/new"
    assert_empty ActionMailer::Base.deliveries
  end

  test "the RSVP audience skips households that already answered" do
    h1 = @family.households.create!(name: "Anns")
    h2 = @family.households.create!(name: "Orgs")
    @a.update!(person: @family.people.create!(first_name: "Ann", household: h1))
    @org.update!(person: @family.people.create!(first_name: "Thea", household: h2))
    r = @family.reunions.create!(title: "Reunion 2027", rsvp_by: Date.current + 10)
    r.rsvps.create!(household: h1, status: "attending", adults: 2)
    got = Announcement.recipients(@family, "rsvp_pending", r).map { |m| m.user.email }
    assert_equal [ "org@example.test" ], got
  end

  test "the organizers-only audience reaches only organizers" do
    got = Announcement.recipients(@family, "organizers").map { |m| m.user.email }
    assert_equal [ "org@example.test" ], got
  end

  test "an empty message is refused" do
    sign_in(@org)
    post "/f/ann-test/announcements", params: send_params(body: "")
    assert_response :unprocessable_entity
    assert_empty ActionMailer::Base.deliveries
  end

  test "another family's organizer cannot reach this family's messages" do
    other = Family.create!(name: "Other", slug: "other")
    ou = User.create!(email: "x@example.test", password: PW, name: "X")
    other.memberships.create!(user: ou, role: "organizer")
    post user_session_path, params: { user: { email: ou.email, password: PW } }
    get "/f/ann-test/announcements"
    assert_response :not_found
  end
end
