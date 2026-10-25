require "test_helper"

class BoardPostTest < ActiveSupport::TestCase
  test "a topic needs a title; a reply does not and loses any it was given" do
    u = make_user
    assert_not u.board_posts.new(body: "hi").valid?
    t = u.board_posts.create!(title: "Plans", body: "hi")
    r = u.board_posts.create!(parent: t, title: "ignored", body: "yes", pinned: true)
    assert_nil r.title
    assert_not r.pinned
  end

  test "replies cannot nest under replies" do
    u = make_user
    t = u.board_posts.create!(title: "Plans", body: "hi")
    r = u.board_posts.create!(parent: t, body: "yes")
    assert_not u.board_posts.new(parent: r, body: "no").valid?
  end

  test "authors can remove their own post for 48 hours; the admin always can" do
    a, b, admin = make_user, make_user, make_user(admin: true)
    t = a.board_posts.create!(title: "Plans", body: "hi")
    assert t.removable_by?(a)
    assert_not t.removable_by?(b)
    assert t.removable_by?(admin)
    t.update_columns(created_at: 3.days.ago)
    assert_not t.reload.removable_by?(a)
    assert t.removable_by?(admin)
  end
end
