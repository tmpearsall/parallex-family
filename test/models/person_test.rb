require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "death before birth is invalid" do
    p = Person.new(first_name: "X", birth_date: "2000-01-01", death_date: "1999-01-01")
    assert_not p.valid?
  end

  test "hidden details are visible only to admins and the person" do
    kid = make_person("Kid", hide_details: true)
    other = make_user
    me = make_user(person: kid)
    admin = make_user(admin: true)
    assert_not kid.details_visible_to?(other)
    assert kid.details_visible_to?(me)
    assert kid.details_visible_to?(admin)
  end

  test "names are squished and blanks become nil" do
    p = Person.create!(first_name: "  Ann  ", last_name: " ", email: "")
    assert_equal "Ann", p.first_name
    assert_nil p.last_name
    assert_nil p.email
  end
end
