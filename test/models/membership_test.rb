require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "one membership per user per family" do
    u = member
    assert_not Membership.new(family: family, user: u).valid?
  end

  test "the last organizer cannot be demoted" do
    boss = member(role: "organizer")
    m = boss.memberships.first
    m.role = "member"
    assert_not m.valid?
    member(role: "organizer")
    assert m.valid?
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
