require "test_helper"

class FamiliesTest < ActionDispatch::IntegrationTest
  test "one family goes straight in; several show a picker; none explains" do
    one = member
    sign_in one
    get root_path
    assert_redirected_to family_home_path(family: "rowe")

    many = member
    Membership.create!(family: make_family("Lee"), user: many, role: "member")
    sign_in many
    get root_path
    assert_response :success
    assert_match(/Rowe/, response.body)
    assert_match(/Lee/, response.body)

    sign_in make_user
    get root_path
    assert_match(/not in an organization yet/, response.body)
  end

  test "an account's display name is its own" do
    u = member
    sign_in u
    patch account_path, params: { name: "New Name" }
    assert_equal "New Name", u.reload.name
  end
end
