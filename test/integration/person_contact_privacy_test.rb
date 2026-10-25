require "test_helper"

class PersonContactPrivacyTest < ActionDispatch::IntegrationTest
  PW = "Str0ng!Pass#1".freeze

  setup do
    @family = Family.create!(name: "Priv Test", slug: "priv-test")
    @org = User.create!(email: "o@example.test", password: PW, name: "O")
    @mem = User.create!(email: "m@example.test", password: PW, name: "M")
    @family.memberships.create!(user: @org, role: "organizer")
    @family.memberships.create!(user: @mem, role: "member")
    @open = @family.people.create!(first_name: "Open", street1: "1 Open St", city: "Ames", state: "IA", zip: "50010", phone: "555-0100", phone2: "555-0101")
    @kid = @family.people.create!(first_name: "Kid", street1: "Box 77 Campus Hall", city: "Hanover", state: "NH", zip: "03755", phone2: "555-0199", hide_details: true)
  end

  def sign_in(u) = post(user_session_path, params: { user: { email: u.email, password: PW } })

  test "a member sees an open person's mailing address and second phone but not a private person's" do
    sign_in(@mem)
    get "/f/priv-test/people/#{@open.id}"
    assert_includes response.body, "1 Open St, Ames, IA 50010"
    assert_includes response.body, "Phone 2: 555-0101"
    get "/f/priv-test/people/#{@kid.id}"
    assert_not_includes response.body, "Campus Hall"
    assert_not_includes response.body, "555-0199"
  end

  test "an organizer sees the private person's details" do
    sign_in(@org)
    get "/f/priv-test/people/#{@kid.id}"
    assert_includes response.body, "Box 77 Campus Hall, Hanover, NH 03755"
  end

  test "the edit form saves the new fields" do
    sign_in(@org)
    patch "/f/priv-test/people/#{@open.id}", params: { person: { street2: "Apt 2", phone2: "555-0111" } }
    assert_equal "Apt 2", @open.reload.street2
    assert_equal "555-0111", @open.phone2
  end
end
