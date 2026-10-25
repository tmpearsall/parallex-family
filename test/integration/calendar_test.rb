require "test_helper"

class CalendarTest < ActionDispatch::IntegrationTest
  setup { @f = family.slug }

  test "the month page shows events, birthdays and the subscription address, and moves between months" do
    u = member
    sign_in u
    family.events.create!(title: "Planning call", starts_on: Date.current.beginning_of_month + 9)
    make_person("Maya", birth_date: "2010-#{format('%02d', Date.current.month)}-09")
    get calendar_path(family: @f)
    assert_response :success
    assert_match(/Planning call/, response.body)
    assert_match(/Maya&#39;s birthday|Maya's birthday/, response.body)
    assert_match(%r{/calendar/[\w-]+\.ics}, response.body)
    get calendar_path(family: @f, month: "2030-02")
    assert_response :success
    assert_match(/February 2030/, response.body)
    get calendar_path(family: @f, month: "garbage")
    assert_response :success
  end

  test "members add events, see who added them, and remove their own for 48 hours" do
    u = member(name: "Thea")
    sign_in u
    assert_difference "Event.count", 1 do
      post events_path(family: @f), params: { event: { title: "Cookout", starts_on: "2027-07-03", time_note: "2 pm", location: "Park" } }
    end
    e = family.events.last
    assert_equal u.id, e.created_by_id
    get event_path(e, family: @f)
    assert_match(/Added by Thea/, response.body)
    assert_difference "Event.count", -1 do
      delete event_path(e, family: @f)
    end
  end

  test "a member cannot remove someone else's event or an old one; an organizer can" do
    a = member
    e = family.events.create!(title: "Theirs", starts_on: "2027-07-03", created_by_id: a.id)
    sign_in member
    delete event_path(e, family: @f)
    assert Event.exists?(e.id)
    sign_in a
    e.update_columns(created_at: 3.days.ago)
    delete event_path(e, family: @f)
    assert Event.exists?(e.id)
    sign_in member(role: "organizer")
    delete event_path(e, family: @f)
    assert_not Event.exists?(e.id)
  end

  test "a bad event is rejected" do
    sign_in member
    assert_no_difference "Event.count" do
      post events_path(family: @f), params: { event: { title: "", starts_on: "2027-07-03" } }
    end
    assert_response :unprocessable_entity
  end

  test "another family's calendar and events are out of reach" do
    lee = make_family("Lee")
    e = lee.events.create!(title: "Lee secret", starts_on: "2027-03-10")
    sign_in member
    get calendar_path(family: @f)
    assert_no_match(/Lee secret/, response.body)
    get event_path(e, family: @f)
    assert_response :not_found
    get calendar_path(family: lee.slug)
    assert_response :not_found
  end

  test "an anniversary date is saved from the person's page" do
    sign_in member
    a, b = make_person("Ann"), make_person("Bob")
    rel = pair(a, b)
    patch relationship_path(rel, family: @f), params: { relationship: { started_on: "1995-06-17" } }
    assert_equal Date.new(1995, 6, 17), rel.reload.started_on
  end
end

class CalendarFeedTest < ActionDispatch::IntegrationTest
  setup do
    @u = member
    @m = @u.memberships.first
    @token = @m.calendar_token!
    family.events.create!(title: "Cookout, with; special\\chars", starts_on: "2027-07-03", ends_on: "2027-07-04", location: "Park")
    Reunion.create!(family: family, title: "Rowe reunion", starts_on: "2027-07-02")
    make_person("Maya", birth_date: "2010-05-09")
    make_person("Kid", birth_date: "2014-02-02", hide_details: true)
  end

  test "the feed is valid iCalendar with escaped text, yearly birthdays, and no private details" do
    get calendar_feed_path(token: @token, format: "ics")
    assert_response :success
    assert_match(%r{text/calendar}, response.content_type)
    body = response.body
    assert body.start_with?("BEGIN:VCALENDAR\r\n") && body.end_with?("END:VCALENDAR\r\n")
    assert_equal body.scan("BEGIN:VEVENT").size, body.scan("END:VEVENT").size
    assert_includes body, "SUMMARY:Cookout\\, with\; special\\\\chars"
    assert_includes body, "DTSTART;VALUE=DATE:20270703"
    assert_includes body, "DTEND;VALUE=DATE:20270705"
    assert_includes body, "LOCATION:Park"
    assert_includes body, "SUMMARY:Maya's birthday"
    assert_includes body, "RRULE:FREQ=YEARLY"
    assert_not_includes body, "Kid"
    assert body.lines.all? { |l| l.chomp.bytesize <= 75 }
  end

  test "a wrong or replaced token gets nothing, and the feed needs no sign-in" do
    get calendar_feed_path(token: "nonsense", format: "ics")
    assert_response :not_found
    old = @token
    sign_in @u
    post calendar_reset_link_path(family: family.slug)
    get calendar_feed_path(token: old, format: "ics")
    assert_response :not_found
    sign_out :user
    get calendar_feed_path(token: @m.reload.calendar_token, format: "ics")
    assert_response :success
  end

  test "a member's feed carries only their own family" do
    lee = make_family("Lee")
    lee.events.create!(title: "Lee secret", starts_on: "2027-03-10")
    get calendar_feed_path(token: @token, format: "ics")
    assert_not_includes response.body, "Lee secret"
  end

  test "an organizer's feed includes private children's birthdays; a member's does not" do
    boss = member(role: "organizer")
    get calendar_feed_path(token: boss.memberships.first.calendar_token!, format: "ics")
    assert_includes response.body, "Kid's birthday"
  end
end
