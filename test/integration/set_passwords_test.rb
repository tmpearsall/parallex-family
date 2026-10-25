require "test_helper"

class SetPasswordsTest < ActionDispatch::IntegrationTest
  test "a platform-issued link sets a password once" do
    u = make_user
    token = u.issue_set_password_token!
    get set_password_path(token)
    assert_response :success
    patch set_password_path(token), params: { name: "Renamed", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to root_path
    get set_password_path(token)
    assert_response :gone
  end

  test "an expired link is refused and a weak password is rejected" do
    u = make_user
    token = u.issue_set_password_token!
    u.update_columns(reset_password_sent_at: 8.days.ago)
    get set_password_path(token)
    assert_response :gone
    t2 = u.issue_set_password_token!
    patch set_password_path(t2), params: { name: "X", password: "password", password_confirmation: "password" }
    assert_response :unprocessable_entity
  end
end
