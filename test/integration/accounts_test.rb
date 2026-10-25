require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  test "an admin invites someone and the one-time link sets a password once" do
    sign_in make_user(admin: true)
    post admin_users_path, params: { user: { email: "cousin@example.test", name: "Cousin" } }
    assert_response :success
    url = response.body[%r{https?://[^\s<]+/set_password/[^\s<]+}]
    assert url, "link shown"
    token = url.split("/").last
    sign_out :user
    get set_password_path(token)
    assert_response :success
    patch set_password_path(token), params: { name: "Cousin", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to root_path
    get set_password_path(token)
    assert_response :gone
  end

  test "an expired link is refused" do
    u = make_user
    token = u.issue_set_password_token!
    u.update_columns(reset_password_sent_at: 8.days.ago)
    get set_password_path(token)
    assert_response :gone
  end

  test "a weak password is rejected" do
    u = make_user
    token = u.issue_set_password_token!
    patch set_password_path(token), params: { name: "X", password: "password", password_confirmation: "password" }
    assert_response :unprocessable_entity
  end
end
