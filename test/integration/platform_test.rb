require "test_helper"

class PlatformTest < ActionDispatch::IntegrationTest
  setup do
    @admin = make_user(platform_admin: true)
    sign_in @admin
  end

  test "the platform administrator creates a family with its first organizer's invitation" do
    assert_difference [ "Family.count", "Invitation.count" ], 1 do
      post platform_families_path, params: { family: { name: "The Lee Family", organizer_email: "boss@example.test" } }
    end
    assert_response :success
    f = Family.find_by!(slug: "the-lee-family")
    assert_equal "organizer", f.invitations.first.role
    assert_match(%r{/invite/}, response.body)
  end

  test "the platform page lists counts but never a family's people or board" do
    make_person("Secretname")
    member(role: "organizer")
    get platform_families_path
    assert_match(/Rowe/, response.body)
    assert_no_match(/Secretname/, response.body)
  end

  test "a platform administrator is not a member and cannot read a family" do
    family
    get "/f/rowe/people"
    assert_response :not_found
  end

  test "a bad slug or missing email creates nothing" do
    assert_no_difference "Family.count" do
      post platform_families_path, params: { family: { name: "X", slug: "platform", organizer_email: "a@example.test" } }
      post platform_families_path, params: { family: { name: "Y", organizer_email: "" } }
    end
  end

  test "password link for an account" do
    u = make_user(email: "forgot@example.test")
    post platform_password_link_path, params: { email: "forgot@example.test" }
    assert_response :success
    token = response.body[%r{/set_password/([\w-]+)}, 1]
    assert_equal u, User.find_by(reset_password_token: User.set_password_digest(token))
  end
end
