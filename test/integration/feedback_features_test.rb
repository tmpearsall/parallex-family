require "test_helper"

# Features that came from the first relative to use the app: removing a person, who posted what, phone numbers,
# adding several people to a household at once, and linking yourself to your place in the tree.
class FeedbackFeaturesTest < ActionDispatch::IntegrationTest
  setup { @f = family.slug }

  # --- removing a person
  test "a member can remove someone they just added" do
    u = member
    sign_in u
    p = Person.create!(family: family, first_name: "Oops", created_by_id: u.id)
    assert_difference "Person.count", -1 do
      delete person_path(p, family: @f)
    end
  end

  test "a member cannot remove someone else's person, an old one, or one with an account" do
    u = member
    sign_in u
    others = Person.create!(family: family, first_name: "Theirs", created_by_id: member.id)
    old = Person.create!(family: family, first_name: "Old", created_by_id: u.id)
    old.update_columns(created_at: 3.days.ago)
    linked = Person.create!(family: family, first_name: "Linked", created_by_id: u.id)
    member(person: linked)
    [ others, old, linked ].each do |p|
      delete person_path(p, family: @f)
      assert Person.exists?(p.id), p.first_name
    end
  end

  test "an organizer can remove anyone" do
    sign_in member(role: "organizer")
    p = make_person("Gone")
    assert_difference "Person.count", -1 do
      delete person_path(p, family: @f)
    end
  end

  test "the person page tells a member how removal works" do
    sign_in member
    get person_path(make_person("Ann"), family: @f)
    assert_match(/ask an organizer/i, response.body)
  end

  # --- linking yourself
  test "a member links their own account to their place in the tree, once" do
    u = member
    sign_in u
    me, other = make_person("Me"), make_person("Other")
    post claim_person_path(me, family: @f)
    assert_equal me.id, u.memberships.first.person_id
    post claim_person_path(other, family: @f)
    assert_nil other.memberships.first, "already linked to someone"
    sign_in member
    post claim_person_path(me, family: @f)
    assert_equal 1, me.memberships.count, "already claimed by someone else"
  end

  test "a person from another family cannot be claimed" do
    u = member
    sign_in u
    z = make_person("Zed", "Lee", fam: make_family("Lee"))
    post claim_person_path(z, family: @f)
    assert_response :not_found
  end

  # --- who posted
  test "people and households show who added them" do
    u = member(name: "Thea")
    sign_in u
    post people_path(family: @f), params: { person: { first_name: "Maya" } }
    get person_path(family.people.find_by!(first_name: "Maya"), family: @f)
    assert_match(/Added by Thea/, response.body)
    post households_path(family: @f), params: { household: { name: "The Thompsons" } }
    get household_path(family.households.find_by!(name: "The Thompsons"), family: @f)
    assert_match(/Added by Thea/, response.body)
  end

  test "an RSVP shows who answered it" do
    u = member(name: "Thea")
    sign_in u
    r = Reunion.create!(family: family, title: "Reunion")
    h = Household.create!(family: family, name: "The Rowes")
    post reunion_rsvps_path(r, family: @f), params: { rsvp: { household_id: h.id, status: "maybe" } }
    get reunion_path(r, family: @f)
    assert_match(/Thea/, response.body)
  end

  # --- phone numbers
  test "phone numbers are saved, shown to the family, and hidden for a child's private details" do
    sign_in member
    post people_path(family: @f), params: { person: { first_name: "Ann", phone: "(555) 555-0123" } }
    ann = family.people.find_by!(first_name: "Ann")
    assert_equal "(555) 555-0123", ann.phone
    get person_path(ann, family: @f)
    assert_match(/555-0123/, response.body)
    kid = make_person("Kid", hide_details: true, phone: "(555) 555-9999")
    get person_path(kid, family: @f)
    assert_no_match(/555-9999/, response.body)
  end

  test "a phone field with letters is rejected" do
    assert_not Person.new(family: family, first_name: "X", phone: "call me").valid?
    assert Person.new(family: family, first_name: "X", phone: "+1 (240) 555-0100 x12").valid?
  end

  # --- several people at once
  test "several people are added to a household at once, with a default last name" do
    u = member
    sign_in u
    h = Household.create!(family: family, name: "The Thompsons")
    assert_difference "Person.count", 3 do
      post add_people_household_path(h, family: @f), params: { names: "Maya Thompson\nJordan Thompson\n\nSam", default_last: "Thompson" }
    end
    assert_equal [ "Jordan Thompson", "Maya Thompson", "Sam Thompson" ], h.people.by_name.map(&:display_name)
    assert_equal [ u.id ], h.people.pluck(:created_by_id).uniq
    assert_not h.people.first.hide_details
  end

  test "people added as children are private by default" do
    sign_in member
    h = Household.create!(family: family, name: "The Thompsons")
    post add_people_household_path(h, family: @f), params: { names: "Kid One\nKid Two", children: "1" }
    assert h.people.all?(&:hide_details)
  end

  test "an empty list or another family's household adds nobody" do
    sign_in member
    h = Household.create!(family: family, name: "The Thompsons")
    assert_no_difference "Person.count" do
      post add_people_household_path(h, family: @f), params: { names: "  \n " }
    end
    lee = Household.create!(family: make_family("Lee"), name: "The Lees")
    assert_no_difference "Person.count" do
      post add_people_household_path(lee, family: @f), params: { names: "Intruder" }
    end
    assert_response :not_found
  end

  # --- who's here
  test "members see names but not emails; organizers see emails; other families never appear" do
    member(name: "Ann", email: "ann@example.test")
    member(fam: make_family("Lee"), name: "Outsider", email: "out@example.test")
    sign_in member(name: "Bo", email: "bo@example.test")
    get directory_path(family: @f)
    assert_match(/Ann/, response.body)
    assert_no_match(/ann@example|bo@example/, response.body)
    assert_no_match(/Outsider|out@example/, response.body)
    sign_in member(role: "organizer", name: "Boss", email: "boss@example.test")
    get directory_path(family: @f)
    assert_match(/ann@example\.test/, response.body)
  end
end
