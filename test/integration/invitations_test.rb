require "test_helper"

class InvitationsTest < ActionDispatch::IntegrationTest
  test "the sign-up form can show what is being typed and says whether the two passwords match" do
    _, raw = Invitation.issue!(family: family, email: "show@example.test")
    get invitation_path(raw)
    assert_response :success
    assert_includes response.body, "Show what I type"
    assert_includes response.body, 'id="match"'
    assert_includes response.body, 'type="password" name="password"'
  end

  test "a display name that is the password is refused, and nothing is created" do
    inv, raw = Invitation.issue!(family: family, email: "typo@example.test")
    assert_no_difference "User.count" do
      post register_invitation_path(raw), params: { name: "Abcdef1!xyz", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "That looks like your password"
    assert_nil inv.reload.accepted_at
    post register_invitation_path(raw), params: { name: "Typo", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to family_home_path(family: "rowe")
  end

  test "a new person opens a link, makes an account, joins, and the link works once" do
    inv, raw = Invitation.issue!(family: family, email: "cousin@example.test")
    get invitation_path(raw)
    assert_response :success
    assert_match(/Join Rowe/, response.body)
    post register_invitation_path(raw), params: { name: "Cousin", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to family_home_path(family: "rowe")
    user = User.find_by!(email: "cousin@example.test")
    assert_equal [ "member" ], user.memberships.map(&:role)
    assert inv.reload.accepted_at
    get invitation_path(raw)
    assert_response :gone
  end

  test "someone who already has an account signs in and joins" do
    existing = make_user(email: "ann@example.test")
    _, raw = Invitation.issue!(family: family, email: "ann@example.test")
    get invitation_path(raw)
    assert_match(/already has an account/, response.body)
    sign_in existing
    post accept_invitation_path(raw)
    assert_redirected_to family_home_path(family: "rowe")
    assert existing.memberships.exists?(family_id: family.id)
  end

  test "registering over an existing email is refused" do
    make_user(email: "ann@example.test")
    _, raw = Invitation.issue!(family: family, email: "ann@example.test")
    assert_no_difference "User.count" do
      post register_invitation_path(raw), params: { name: "Ann", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    end
    assert_redirected_to invitation_path(raw)
  end

  test "a weak password or missing name creates nothing" do
    _, raw = Invitation.issue!(family: family, email: "new@example.test")
    assert_no_difference [ "User.count", "Membership.count" ] do
      post register_invitation_path(raw), params: { name: "New", password: "password", password_confirmation: "password" }
      assert_response :unprocessable_entity
      post register_invitation_path(raw), params: { name: "", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
      assert_response :unprocessable_entity
    end
  end

  test "an expired or unknown link is refused" do
    inv, raw = Invitation.issue!(family: family, email: "x@example.test")
    inv.update_columns(expires_at: 1.minute.ago)
    get invitation_path(raw)
    assert_response :gone
    get invitation_path("nonsense")
    assert_response :gone
  end

  test "the invitation brings the invited role and tree person with it" do
    p = make_person("Ann")
    _, raw = Invitation.issue!(family: family, email: "ann@example.test", role: "organizer", person: p)
    post register_invitation_path(raw), params: { name: "Ann", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    m = User.find_by!(email: "ann@example.test").memberships.first
    assert_equal [ "organizer", p.id ], [ m.role, m.person_id ]
  end
end
