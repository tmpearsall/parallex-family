require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "death before birth is invalid" do
    assert_not Person.new(family: family, first_name: "X", birth_date: "2000-01-01", death_date: "1999-01-01").valid?
  end

  test "hidden details are visible only to organizers and the person" do
    kid = make_person("Kid", hide_details: true)
    plain = member
    me = member(person: kid)
    boss = member(role: "organizer")
    m = ->(u) { u.memberships.first }
    assert_not kid.details_visible_to?(m.(plain))
    assert kid.details_visible_to?(m.(me))
    assert kid.details_visible_to?(m.(boss))
  end

  test "names are squished and blanks become nil" do
    p = Person.create!(family: family, first_name: "  Ann  ", last_name: " ", email: "")
    assert_equal "Ann", p.first_name
    assert_nil p.last_name
    assert_nil p.email
  end

  test "a household from another family is rejected" do
    h = Household.create!(family: make_family("Lee"), name: "The Lees")
    assert_not Person.new(family: family, first_name: "X", household: h).valid?
  end
end
