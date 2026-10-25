require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a display name that is the password, or contains it, is refused" do
    assert User.name_looks_like_password?("Sunny@2027", "Sunny@2027")
    assert User.name_looks_like_password?("sunny@2027", "Sunny@2027")
    assert User.name_looks_like_password?("Sunny@2027 Smith", "Sunny@2027")
    assert_not User.name_looks_like_password?("Sunny", "Sunny@2027")
    assert_not User.name_looks_like_password?("Thea", "Str0ng!Pass#1")
    assert_not User.name_looks_like_password?("", "whatever1!")
  end
end
