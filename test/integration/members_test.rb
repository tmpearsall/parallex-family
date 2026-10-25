require "test_helper"

class MembersTest < ActionDispatch::IntegrationTest
  setup do
    @boss = member(role: "organizer", name: "Boss")
    sign_in @boss
    @f = family.slug
  end

  test "an organizer invites several relatives at once and gets one link each" do
    assert_difference "Invitation.count", 2 do
      post members_path(family: @f), params: { invite: { emails: "a@example.test, B@example.test\na@example.test", role: "member" } }
    end
    assert_response :success
    assert_equal 2, response.body.scan(%r{/invite/[\w-]+}).uniq.size
    assert_equal [ @boss.id ], Invitation.pluck(:invited_by_id).uniq
  end

  test "someone already in the family is not re-invited" do
    member(email: "in@example.test")
    assert_no_difference "Invitation.count" do
      post members_path(family: @f), params: { invite: { emails: "in@example.test" } }
    end
    assert_match(/Already a member/, response.body)
  end

  test "a bad address is reported and the rest still go out" do
    assert_difference "Invitation.count", 1 do
      post members_path(family: @f), params: { invite: { emails: "not-an-email ok@example.test" } }
    end
    assert_match(/ok@example.test/, response.body)
  end

  test "an invitation can be tied to a person in the tree, but not for several emails" do
    p = make_person("Ann")
    post members_path(family: @f), params: { invite: { emails: "ann@example.test", person_id: p.id } }
    assert_equal p.id, Invitation.last.person_id
    post members_path(family: @f), params: { invite: { emails: "x@example.test y@example.test", person_id: p.id } }
    assert_nil Invitation.where(email: "x@example.test").first.person_id
  end

  test "organizers can withdraw an invitation" do
    inv, = Invitation.issue!(family: family, email: "x@example.test")
    delete revoke_member_path(inv, family: @f)
    assert_not Invitation.exists?(inv.id)
  end

  test "promoting, demoting and removing members, but never the last organizer" do
    other = member
    m = other.memberships.first
    patch member_path(m, family: @f, role: "organizer")
    assert_equal "organizer", m.reload.role
    patch member_path(m, family: @f, role: "member")
    assert_equal "member", m.reload.role
    delete member_path(m, family: @f)
    assert_not Membership.exists?(m.id)
    mine = @boss.memberships.first
    delete member_path(mine, family: @f)
    assert Membership.exists?(mine.id), "the last organizer stays"
  end

  test "an organizer cannot manage another family's invitations or members" do
    lee = make_family("Lee")
    inv, = Invitation.issue!(family: lee, email: "x@example.test")
    lm = member(fam: lee).memberships.first
    get members_path(family: @f)   # establish the session cookie first
    assert_response :success
    delete revoke_member_path(inv, family: @f)
    assert_response :not_found
    assert Invitation.exists?(inv.id)
    delete member_path(lm, family: @f)
    assert_response :not_found
    assert Membership.exists?(lm.id)
  end

  test "an organizer renames the family; a member cannot; the address stays" do
    patch settings_path(family: @f), params: { name: "The Rowe Family" }
    assert_equal "The Rowe Family", family.reload.name
    assert_equal @f, family.slug
    sign_in member
    patch settings_path(family: @f), params: { name: "Hijacked" }
    assert_response :forbidden
    assert_equal "The Rowe Family", family.reload.name
  end
end
