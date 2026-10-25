require "test_helper"

class MeetingsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @org = member(role: "organizer", name: "Thea", email: "thea@example.test")
    @mem = member(role: "member", name: "Plain", email: "plain@example.test")
    @f = family.slug
    @reunion = family.reunions.create!(title: "Reunion 2027", starts_on: Date.current + 60)
    @meeting = family.events.create!(title: "Reunion prep", starts_on: Date.current + 1, organizers_only: true, repeat: "weekly", reunion: @reunion, time_note: "7 pm")
    @open = family.events.create!(title: "Cookout", starts_on: Date.current + 3)
  end

  test "a standing meeting stops at the reunion when no end date is given" do
    assert_equal @reunion.starts_on, @meeting.repeat_until
    days = @meeting.occurrence_days(Date.current, Date.current + 365)
    assert_equal Date.current + 1, days.first
    assert days.all? { |d| d <= @reunion.starts_on }
    assert days.each_cons(2).all? { |a, b| (b - a).to_i == 7 }
  end

  test "every two weeks, monthly, and the two-year cap" do
    e = family.events.create!(title: "Biweekly", starts_on: Date.current, repeat: "biweekly", repeat_until: Date.current + 60)
    assert_equal [ 0, 14, 28, 42, 56 ], e.occurrence_days(Date.current, Date.current + 90).map { |d| (d - Date.current).to_i }
    m = family.events.create!(title: "Monthly", starts_on: Date.new(2027, 1, 31), repeat: "monthly", repeat_until: Date.new(2027, 4, 30))
    assert_equal [ "2027-01-31", "2027-02-28", "2027-03-31", "2027-04-30" ], m.occurrence_days(Date.new(2027, 1, 1), Date.new(2027, 12, 31)).map(&:to_s)
    open_ended = family.events.create!(title: "Forever", starts_on: Date.current, repeat: "weekly")
    assert_operator open_ended.occurrence_days(Date.current, Date.current + 5.years).size, :<=, 106
  end

  test "organizers see the meeting on the calendar and members do not" do
    sign_in @org
    items = CalendarItems.new(family: family, membership: @org.memberships.first).between(Date.current, Date.current + 30)
    assert_equal 5, items.count { |i| i.title == "Reunion prep" }
    items = CalendarItems.new(family: family, membership: @mem.memberships.first).between(Date.current, Date.current + 30)
    assert_equal 0, items.count { |i| i.title == "Reunion prep" }
    assert_equal 1, items.count { |i| i.title == "Cookout" }
  end

  test "a member gets a 404 for a meeting and cannot make one" do
    sign_in @mem
    get event_path(@meeting, family: @f)
    assert_response :not_found
    sign_in @mem   # a 404 ends the test session
    post events_path(family: @f), params: { event: { title: "Sneaky", starts_on: Date.current.to_s, organizers_only: "1", repeat: "weekly" } }
    e = family.events.find_by(title: "Sneaky")
    assert_not e.organizers_only
    assert_equal "none", e.repeat
  end

  test "the phone calendar feed carries the meeting for organizers only" do
    om = @org.memberships.first
    mm = @mem.memberships.first
    assert_includes IcsFeed.new(family: family, membership: om).to_s, "Reunion prep"
    assert_not_includes IcsFeed.new(family: family, membership: mm).to_s, "Reunion prep"
  end

  test "cancelling one date leaves the series and can be undone" do
    sign_in @org
    day = @meeting.starts_on + 7
    patch skip_event_path(@meeting, date: day.to_s, family: @f)
    assert_not_includes @meeting.reload.occurrence_days(Date.current, Date.current + 30), day
    assert_includes @meeting.occurrence_days(Date.current, Date.current + 30), @meeting.starts_on
    get event_path(@meeting, family: @f)
    assert_includes response.body, "Bring back"
    patch unskip_event_path(@meeting, date: day.to_s, family: @f)
    assert_includes @meeting.reload.occurrence_days(Date.current, Date.current + 30), day
    patch skip_event_path(@meeting, date: (day + 1).to_s, family: @f)   # not an occurrence
    assert_empty Array(@meeting.reload.skipped_dates)
  end

  test "a member cannot cancel dates" do
    sign_in @mem
    patch skip_event_path(@meeting, date: @meeting.starts_on.to_s, family: @f)
    assert_response :not_found
  end

  test "tomorrow's meeting reminds organizers each week and never members" do
    om = @org.memberships.first
    mm = @mem.memberships.first
    run = ReminderRunner.new(today: Date.current)
    assert_equal 1, run.due_items(om).count { |i| i.text.include?("Reunion prep") }
    assert_equal 0, run.due_items(mm).count { |i| i.text.include?("Reunion prep") }
    next_week = ReminderRunner.new(today: Date.current + 7)
    items = next_week.due_items(om).select { |i| i.text.include?("Reunion prep") }
    assert_equal 1, items.size
    assert_not_equal run.due_items(om).find { |i| i.text.include?("Reunion prep") }.key, items.first.key
  end

  test "the meeting form is offered to organizers and prefilled from the Admin card" do
    sign_in @org
    get new_event_path(family: @f, meeting: 1, repeat: "weekly", title: "Planning meeting")
    assert_response :success
    assert_includes response.body, "Organizers only"
    assert_includes response.body, "Planning meeting"
    get admin_path(family: @f)
    assert_includes response.body, "Organizers' meetings"
  end
end
