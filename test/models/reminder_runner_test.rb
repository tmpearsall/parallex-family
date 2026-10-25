require "test_helper"

class ReminderRunnerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def run_on(date) = ReminderRunner.new(today: Date.parse(date)).run
  def last_mail = ActionMailer::Base.deliveries.last

  setup do
    ActionMailer::Base.deliveries.clear
    @house = Household.create!(family: family, name: "The Rowes")
    @ann = make_person("Ann", household: @house)
    @u = member(person: @ann, name: "Ann", email: "ann@example.test")
    @m = @u.memberships.first
    @reunion = Reunion.create!(family: family, title: "Rowe reunion", starts_on: "2027-07-02", rsvp_by: "2027-06-01", location_name: "Elizabeth Park")
  end

  test "an unanswered household is nudged 14, 7, 3, 1 and 0 days before the RSVP date, once each" do
    [ "2027-05-18", "2027-05-25", "2027-05-29", "2027-05-31", "2027-06-01" ].each do |d|
      assert_emails(1) { run_on(d) }
      assert_includes last_mail.text_part.body.to_s, "The Rowes hasn't answered"
      assert_emails(0) { run_on(d) }   # the same day again sends nothing
    end
    assert_emails(0) { run_on("2027-05-20") }   # not a reminder day
  end

  test "a household that has answered is not nudged" do
    @reunion.rsvps.create!(household: @house, status: "attending", adults: 2)
    assert_emails(0) { run_on("2027-05-25") }
  end

  test "a member with no household is asked to answer for their household" do
    other = member(email: "bo@example.test").memberships.first
    run_on("2027-05-25")
    mail = ActionMailer::Base.deliveries.find { |m| m.to == [ "bo@example.test" ] }
    assert_includes mail.text_part.body.to_s, "Please answer for your household"
  end

  test "undated reunions nudge a vote, weekly, only for those who have not voted" do
    r = Reunion.create!(family: family, title: "Lee reunion")
    r.update_columns(created_at: Time.zone.parse("2027-05-01"))
    opt = r.date_options.create!(starts_on: "2027-08-14")
    @reunion.update!(rsvp_by: nil, starts_on: "2027-12-25")
    assert_emails(1) { run_on("2027-05-10") }
    assert_includes last_mail.text_part.body.to_s, "vote on the proposed dates"
    assert_emails(0) { run_on("2027-05-11") }     # same week
    assert_emails(1) { run_on("2027-05-17") }     # next week
    DateVote.create!(date_option: opt, user: @u, answer: "yes")
    assert_emails(0) { run_on("2027-05-24") }
  end

  test "the reunion is announced 30, 7 and 1 days out, not to a household that declined" do
    @reunion.update!(rsvp_by: nil)
    assert_emails(1) { run_on("2027-06-02") }
    assert_includes last_mail.text_part.body.to_s, "in 30 days"
    assert_emails(1) { run_on("2027-06-25") }
    assert_emails(1) { run_on("2027-07-01") }
    assert_includes last_mail.text_part.body.to_s, "tomorrow"
    @reunion.rsvps.create!(household: @house, status: "not_attending")
    ActionMailer::Base.deliveries.clear
    EmailDelivery.delete_all
    assert_emails(0) { run_on("2027-06-25") }
  end

  test "claimed unfinished tasks are reminded weekly inside the last two weeks" do
    @reunion.update!(rsvp_by: nil)
    t = @reunion.tasks.create!(title: "Bring a grill", claimed_by: @u)
    @reunion.tasks.create!(title: "Unclaimed", claimed_by: nil)
    assert_emails(1) { run_on("2027-06-25") }   # 7 days out: also the "upcoming" item, in one digest
    body = last_mail.text_part.body.to_s
    assert_includes body, "You said you'd handle: Bring a grill"
    assert_not_includes body, "Unclaimed"
    t.update!(done: true)
    assert_emails(0) { run_on("2027-06-26") }
  end

  test "an event tomorrow is announced to everyone" do
    @reunion.update!(rsvp_by: nil, starts_on: "2027-12-25")
    family.events.create!(title: "Planning call", starts_on: "2027-03-11", time_note: "7 pm")
    assert_emails(1) { run_on("2027-03-10") }
    assert_includes last_mail.text_part.body.to_s, "Tomorrow: Planning call at 7 pm"
  end

  test "several things due the same day arrive as one email" do
    @reunion.update!(rsvp_by: "2027-06-25", starts_on: "2027-07-02")   # RSVP in 0 days AND the reunion in 7
    @reunion.tasks.create!(title: "Bring a grill", claimed_by: @u)
    assert_emails(1) { run_on("2027-06-25") }
    assert_match(/3 reminders for Rowe/, last_mail.subject)
  end

  test "members who opted out get nothing, and one family's reminders never reach another's members" do
    @m.update!(email_reminders: false)
    lee = make_family("Lee")
    outsider = member(fam: lee, email: "out@example.test")
    assert_emails(0) { run_on("2027-05-25") }
  end

  test "every digest carries an unsubscribe link and header" do
    run_on("2027-05-25")
    assert_match(%r{/unsubscribe/[\w-]+}, last_mail.text_part.body.to_s)
    assert_match(/unsubscribe/, last_mail["List-Unsubscribe"].to_s)
    assert_equal "List-Unsubscribe=One-Click", last_mail["List-Unsubscribe-Post"].to_s
  end

  test "a failed send is not recorded as sent, so the next run tries again" do
    failing = Class.new { def self.with(**) = raise("smtp down") }
    result = ReminderRunner.new(today: Date.parse("2027-05-25"), mailer: failing).run
    assert_equal 1, result[:failed]
    assert_equal 0, EmailDelivery.count
    assert_emails(1) { run_on("2027-05-25") }
  end

  test "private children's details never appear in a reminder" do
    kid = make_person("Kid", household: @house, hide_details: true, birth_date: "2014-02-02", notes: "allergic to nuts")
    run_on("2027-05-25")
    assert_not_includes last_mail.text_part.body.to_s, "allergic"
    assert_not_includes last_mail.text_part.body.to_s, "2014"
  end
end
