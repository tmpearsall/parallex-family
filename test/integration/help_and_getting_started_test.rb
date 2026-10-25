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
    assert_includes response.body, "The map"
    assert_includes response.body, "Where to start: add the people"
    assert_includes response.body, "This is me"
    assert_includes response.body, "mailing address"
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
    assert_includes response.body, "Add the people you know"
    assert_includes response.body, "Find yourself in the list"
    me = @family.people.create!(first_name: "U", phone: "555-0100", street1: "1 St", city: "X", state: "Y", zip: "12345")
    @family.people.create!(first_name: "Kin")
    @m.update!(person: me)
    get "/f/help-test"
    assert_not_includes response.body, "Getting started"
  end

  test "organizers see Admin in the navigation and members do not" do
    get "/f/help-test"
    assert_not_includes response.body, "/f/help-test/admin"
    get "/f/help-test/admin"
    assert_response :forbidden
    @m.update!(role: "organizer")
    get "/f/help-test"
    assert_includes response.body, "/f/help-test/admin"
  end

  test "Where to start is the first and pinned entry on the admin page" do
    @m.update!(role: "organizer")
    get "/f/help-test/admin"
    first_card = response.body[/<div class="card[^"]*">.*?<\/h2>/m]
    assert_includes first_card, "Where to start"
    assert_includes first_card, "pinned"
    assert_includes response.body, "/f/help-test/help#start"
    assert_includes response.body, "No one is on the list yet."
  end

  test "the admin page links every organizer tool" do
    @m.update!(role: "organizer")
    get "/f/help-test/admin"
    assert_response :success
    %w[members surveys announcements/new people/import].each { |p| assert_includes response.body, "/f/help-test/#{p}", p }
  end

  test "the forum lives at /forum, the old /board link redirects, and the page says Forum" do
    get "/f/help-test/forum"
    assert_response :success
    assert_includes response.body, "<h1>Forum</h1>"
    get "/f/help-test/board"
    assert_redirected_to "/f/help-test/forum"
    get "/f/help-test"
    assert_includes response.body, "Forum"
    assert_not_includes response.body, ">Board<"
  end

  test "the help link is in the navigation" do
    get "/f/help-test"
    assert_includes response.body, "/f/help-test/help"
  end
end
