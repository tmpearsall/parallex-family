require "test_helper"

class AccessTest < ActionDispatch::IntegrationTest
  test "everything requires sign-in" do
    [ "/", "/f/rowe", "/f/rowe/tree", "/f/rowe/people", "/f/rowe/forum", "/platform/families" ].each do |path|
      get path
      assert_redirected_to new_user_session_path, path
    end
  end

  test "a signed-in non-member gets a 404 for a family, whatever the page" do
    family
    sign_in make_user
    get root_path   # a first successful request establishes the session cookie
    assert_response :success
    [ "/f/rowe", "/f/rowe/tree", "/f/rowe/people", "/f/rowe/households", "/f/rowe/reunions", "/f/rowe/forum", "/f/rowe/members" ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "responses are never indexable" do
    sign_in member
    get family_home_path(family: family.slug)
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
  end

  test "only organizers see members and only the platform administrator sees the platform pages" do
    sign_in member
    get members_path(family: family.slug)
    assert_response :forbidden
    get platform_families_path
    assert_response :forbidden
  end
end
