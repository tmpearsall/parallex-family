require "test_helper"

# A "group" workspace (a board, a company, a church, an HOA, a planning committee) uses the same machinery with
# event wording and without the family-only features.
class GroupKindTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # Visible words only (route names like /reunions are not on the screen).
  FAMILY_WORDS = /reunion|household|relative|family tree|birthday|anniversar|the family/i
  def visible_text(html) = html.gsub(/<(style|script).*?<\/\1>/m, "").gsub(/<[^>]*>/, " ")

  setup do
    @g = Family.create!(name: "Maple Street HOA", kind: "group")
    @boss = member(fam: @g, role: "organizer", name: "Pat", email: "pat@example.test")
    @f = @g.slug
    sign_in @boss
    Person.create!(family: @g, first_name: "Sam", last_name: "Lee", hide_details: true, created_by_id: @boss.id)
    @team = Household.create!(family: @g, name: "Facilities")
    @picnic = Reunion.create!(family: @g, title: "Annual picnic 2027", starts_on: "2027-06-12", rsvp_by: "2027-05-20")
    @picnic.date_options.create!(starts_on: "2027-06-12")
    @picnic.tasks.create!(title: "Bring a grill")
    @g.events.create!(title: "Committee meeting", starts_on: "2027-03-10")
    get family_home_path(family: @f)   # establish the session
  end

  test "the pages use event and team wording, not reunion and household" do
    [ family_home_path(family: @f), reunions_path(family: @f), reunion_path(@picnic, family: @f), households_path(family: @f),
      household_path(@team, family: @f), new_household_path(family: @f), people_path(family: @f), person_path(@g.people.first, family: @f),
      new_person_path(family: @f), members_path(family: @f), directory_path(family: @f), calendar_path(family: @f),
      new_event_path(family: @f), board_path(family: @f), new_reunion_path(family: @f) ].each do |path|
      get path
      assert_response :success, path
      assert_no_match(FAMILY_WORDS, visible_text(response.body), path)
    end
  end

  test "the words that should be there are there" do
    get reunions_path(family: @f)
    assert_match(/<h1>Events<\/h1>/, response.body)
    get households_path(family: @f)
    assert_match(/<h1>Teams<\/h1>/, response.body)
    get family_home_path(family: @f)
    assert_match(/Maple Street HOA/, response.body)
    get new_event_path(family: @f)
    assert_match(/Add a calendar entry/, response.body)
    assert_match(/Part of an event\?/, response.body)
  end

  test "there is no tree, no relationships, and no birthdays or anniversaries" do
    get tree_path(family: @f)
    assert_response :not_found
    a, b = Person.create!(family: @g, first_name: "A"), Person.create!(family: @g, first_name: "B")
    assert_no_difference "Relationship.count" do
      post person_relationships_path(a, family: @f), params: { relationship: { as: "child", other_id: b.id } }
    end
    assert_response :not_found
    Person.create!(family: @g, first_name: "Bday", birth_date: "1980-#{format('%02d', Date.current.month)}-09")
    get calendar_path(family: @f)
    assert_no_match(/Bday/, response.body)
    feed = IcsFeed.new(family: @g, membership: @boss.memberships.first).to_s
    assert_not_includes feed, "birthday"
  end

  test "the new-person form ignores a relationship request in a group" do
    anchor = Person.create!(family: @g, first_name: "Anchor")
    assert_no_difference "Relationship.count" do
      post people_path(family: @f), params: { person: { first_name: "New" }, relate_to: anchor.id, as: "child" }
    end
  end

  test "an invitation email speaks of a group and an event, not a family reunion" do
    ActionMailer::Base.deliveries.clear
    post members_path(family: @f), params: { invite: { emails: "new@example.test", send_email: "1" } }
    mail = ActionMailer::Base.deliveries.last
    assert_match(/Pat invited you to Maple Street HOA/, mail.subject)
    body = mail.text_part.body.to_s
    assert_match(/plan events together/, body)
    assert_no_match(/reunion|family tree/i, body)
  end

  test "reminders in a group say team and event" do
    m = member(fam: @g, person: Person.create!(family: @g, first_name: "Ann", household: @team), email: "ann@example.test").memberships.first
    ActionMailer::Base.deliveries.clear
    ReminderRunner.new(today: Date.parse("2027-05-13")).run
    body = ActionMailer::Base.deliveries.find { |x| x.to == [ "ann@example.test" ] }.text_part.body.to_s
    assert_match(/Facilities hasn't answered/, body)
    assert_no_match(/household/i, body)
  end

  test "the platform administrator creates a group, and a family workspace is unchanged" do
    sign_in make_user(platform_admin: true)
    get platform_families_path
    post platform_families_path, params: { family: { name: "Acme Board", kind: "group", organizer_email: "boss@acme.test" } }
    assert_equal "group", Family.find_by!(slug: "acme-board").kind
    post platform_families_path, params: { family: { name: "Lee Family", kind: "family", organizer_email: "lee@example.test" } }
    assert_equal "family", Family.find_by!(slug: "lee-family").kind
    post platform_families_path, params: { family: { name: "Odd", kind: "nonsense", organizer_email: "odd@example.test" } }
    assert_nil Family.find_by(slug: "odd")
  end

  test "a family workspace keeps its family words and tree" do
    fam = make_family("Rowe")
    sign_in member(fam: fam, role: "organizer")
    get reunions_path(family: fam.slug)
    assert_match(/<h1>Reunions<\/h1>/, response.body)
    get tree_path(family: fam.slug)
    assert_response :success
  end
end
