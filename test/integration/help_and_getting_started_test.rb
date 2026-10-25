require "test_helper"

class HelpAndGettingStartedTest < ActionDispatch::IntegrationTest
  PW = "Str0ng!Pass#1".freeze

  setup do
    @family = Family.create!(name: "Help Test", slug: "help-test")
    @user = User.create!(email: "u@example.test", password: PW, name: "U")
    @m = @family.memberships.create!(user: @user, role: "member")
    post user_session_path, params: { user: { email: @user.email, password: PW } }
  end

  test "the help page explains the first steps in family words" do
    get "/f/help-test/help"
    assert_response :success
    assert_includes response.body, "Your first five minutes"
    assert_includes response.body, "This is me"
    assert_includes response.body, "Mailing address"
    assert_not_includes response.body, "For organizers"
  end

  test "an organizer also sees the organizer tools" do
    @m.update!(role: "organizer")
    get "/f/help-test/help"
    assert_includes response.body, "Send a reminder"
    assert_includes response.body, "Import from a spreadsheet"
  end

  test "a group workspace says teams and events and skips the tree" do
    g = Family.create!(name: "Maple HOA", slug: "maple-hoa", kind: "group")
    g.memberships.create!(user: @user, role: "member")
    get "/f/maple-hoa/help"
    assert_response :success
    assert_includes response.body, "Teams"
    assert_not_includes response.body, "Add a parent"
  end

  test "the home page shows getting started until each step is done, then not at all" do
    get "/f/help-test"
    assert_includes response.body, "Getting started"
    assert_includes response.body, "Find yourself in the list"
    me = @family.people.create!(first_name: "U", phone: "555-0100", street1: "1 St", city: "X", state: "Y", zip: "12345")
    @family.people.create!(first_name: "Kin")
    @m.update!(person: me)
    get "/f/help-test"
    assert_not_includes response.body, "Getting started"
  end

  test "the help link is in the navigation" do
    get "/f/help-test"
    assert_includes response.body, "/f/help-test/help"
  end
end
