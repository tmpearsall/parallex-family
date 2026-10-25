require "test_helper"

class AccessTest < ActionDispatch::IntegrationTest
  test "everything requires sign-in" do
    %w[/ /tree /people /households /reunions /board /admin/users].each do |path|
      get path
      assert_redirected_to new_user_session_path, path
    end
  end

  test "only an admin sees the accounts page and can pin" do
    sign_in make_user
    get admin_users_path
    assert_response :forbidden
    t = make_user.board_posts.create!(title: "T", body: "b")
    patch board_pin_path(t)
    assert_response :forbidden
  end

  test "responses are never indexable" do
    sign_in make_user
    get root_path
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
  end
end
