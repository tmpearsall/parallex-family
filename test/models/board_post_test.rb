require "test_helper"

class BoardPostTest < ActiveSupport::TestCase
  def post!(user, **a) = BoardPost.create!(family: family, user: user, **a)

  test "a topic needs a title; a reply does not and loses any it was given" do
    u = member
    assert_not BoardPost.new(family: family, user: u, body: "hi").valid?
    t = post!(u, title: "Plans", body: "hi")
    r = post!(u, parent: t, title: "ignored", body: "yes", pinned: true)
    assert_nil r.title
    assert_not r.pinned
  end

  test "replies cannot nest under replies, or cross families" do
    u = member
    t = post!(u, title: "Plans", body: "hi")
    r = post!(u, parent: t, body: "yes")
    assert_not BoardPost.new(family: family, user: u, parent: r, body: "no").valid?
    assert_not BoardPost.new(family: make_family("Lee"), user: u, parent: t, body: "no").valid?
  end

  test "authors remove their own post for 48 hours; an organizer always can" do
    a, b, boss = member, member, member(role: "organizer")
    ms = ->(u) { u.memberships.first }
    t = post!(a, title: "Plans", body: "hi")
    assert t.removable_by?(ms.(a))
    assert_not t.removable_by?(ms.(b))
    assert t.removable_by?(ms.(boss))
    t.update_columns(created_at: 3.days.ago)
    assert_not t.reload.removable_by?(ms.(a))
    assert t.removable_by?(ms.(boss))
  end

  test "a reunion from another family cannot be attached" do
    other = Reunion.create!(family: make_family("Lee"), title: "Lee reunion")
    assert_not BoardPost.new(family: family, user: member, title: "T", body: "b", reunion: other).valid?
  end
end
