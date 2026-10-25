require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "one membership per user per family" do
    u = member
    assert_not Membership.new(family: family, user: u).valid?
  end

  test "the last organizer cannot be demoted, and the owner cannot be demoted while owner" do
    boss = member(role: "organizer")
    m = boss.memberships.first
    assert m.owner?
    m.role = "member"
    assert_not m.valid?
    other = member(role: "organizer").memberships.first
    assert_not m.valid?, "the owner still cannot be demoted"
    other.role = "member"
    assert other.valid?, "another organizer can be demoted while the owner remains"
  end

  test "a linked person must be in the same family" do
    z = make_person("Zed", "Lee", fam: make_family("Lee"))
    assert_not Membership.new(family: family, user: make_user, person: z).valid?
  end

  test "family slugs are url-safe, unique and not reserved" do
    assert_not Family.new(name: "X", slug: "Bad Slug!").valid?
    assert_not Family.new(name: "X", slug: "platform").valid?
    make_family("Rowe")
    assert_not Family.new(name: "Rowe again", slug: "rowe").valid?
  end
end
