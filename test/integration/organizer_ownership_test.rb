require "test_helper"

class OrganizerOwnershipTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @owner = member(role: "organizer", name: "Thea", email: "thea@example.test")
    @org = member(role: "organizer", name: "Cousin", email: "cousin@example.test")
    @mem = member(role: "member", name: "Plain", email: "plain@example.test")
    @f = family.slug
    @om = @owner.memberships.first
    @cm = @org.memberships.first
    @mm = @mem.memberships.first
    ActionMailer::Base.deliveries.clear
  end

  test "the first organizer is the owner and there is only ever one" do
    assert @om.owner?
    assert_not @cm.owner?
    assert_raises(ActiveRecord::RecordNotUnique) { @cm.update_columns(owner: true) }
  end

  test "an organizer who is not the owner cannot invite an organizer, but can invite a member" do
    sign_in @org
    assert_no_difference "Invitation.count" do
      post members_path(family: @f), params: { invite: { emails: "new@example.test", role: "organizer", send_email: "0" } }
    end
    assert_redirected_to members_path(family: @f)
    assert_match(/Only the owner/, flash[:alert])
    assert_difference "Invitation.count", 1 do
      post members_path(family: @f), params: { invite: { emails: "new@example.test", role: "member", send_email: "0" } }
    end
  end

  test "an organizer who is not the owner cannot promote, demote or remove an organizer" do
    sign_in @org
    patch member_path(@mm, family: @f, role: "organizer")
    assert_equal "member", @mm.reload.role
    patch member_path(@om, family: @f, role: "member")
    assert_equal "organizer", @om.reload.role
    delete member_path(@om, family: @f)
    assert Membership.exists?(@om.id)
    assert_empty MembershipEvent.all
  end

  test "an organizer who is not the owner can still remove a member" do
    sign_in @org
    delete member_path(@mm, family: @f)
    assert_not Membership.exists?(@mm.id)
  end

  test "a plain member can do none of it" do
    sign_in @mem
    patch member_path(@cm, family: @f, role: "member")
    assert_response :forbidden
    post make_owner_member_path(@mm, family: @f)
    assert_response :forbidden
  end

  test "the owner promotes and demotes, every organizer is told, and it is logged" do
    sign_in @owner
    patch member_path(@mm, family: @f, role: "organizer")
    assert_equal "organizer", @mm.reload.role
    ev = MembershipEvent.last
    assert_equal "made_organizer", ev.kind
    assert_equal "Plain", ev.target_label
    assert_equal @owner.id, ev.actor_user_id
    to = ActionMailer::Base.deliveries.flat_map(&:to).sort
    assert_equal %w[cousin@example.test plain@example.test thea@example.test], to
    assert_match(/Thea made Plain an organizer/, ActionMailer::Base.deliveries.last.text_part&.body.to_s + ActionMailer::Base.deliveries.last.body.to_s)
    patch member_path(@mm, family: @f, role: "member")
    assert_equal "made_member", MembershipEvent.last.kind
  end

  test "the owner's own role cannot be changed and the owner cannot be removed" do
    sign_in @owner
    patch member_path(@om, family: @f, role: "member")
    assert_equal "organizer", @om.reload.role
    delete member_path(@om, family: @f)
    assert Membership.exists?(@om.id)
  end

  test "the owner can invite an organizer and it is logged" do
    sign_in @owner
    assert_difference "Invitation.count", 1 do
      post members_path(family: @f), params: { invite: { emails: "new@example.test", role: "organizer", send_email: "0" } }
    end
    assert_equal "invited_organizer", MembershipEvent.last.kind
    assert_equal "new@example.test", MembershipEvent.last.target_label
  end

  test "ownership can be handed to an organizer, never to a member, and the old owner stays an organizer" do
    sign_in @owner
    post make_owner_member_path(@mm, family: @f)
    assert_not @mm.reload.owner?
    post make_owner_member_path(@cm, family: @f)
    assert @cm.reload.owner?
    assert_not @om.reload.owner?
    assert @om.organizer?
    assert_equal "ownership_transferred", MembershipEvent.last.kind
    delete destroy_user_session_path
    sign_in @owner   # no longer the owner
    patch member_path(@cm, family: @f, role: "member")
    assert_equal "organizer", @cm.reload.role
    assert @cm.owner?
  end

  test "the Access page shows the owner, the recent changes, and hides the organizer option from non-owners" do
    sign_in @owner
    patch member_path(@mm, family: @f, role: "organizer")
    get members_path(family: @f)
    assert_includes response.body, "Thea (owner)"
    assert_includes response.body, "Recent changes to who organizes"
    assert_includes response.body, ">Organizer</option>"
    delete destroy_user_session_path
    sign_in @org
    get members_path(family: @f)
    assert_not_includes response.body, ">Organizer</option>"
    assert_includes response.body, "Only the owner can add, promote or remove organizers"
  end

  test "the first organizer who accepts an invitation to a new workspace becomes its owner" do
    fresh = Family.create!(name: "Fresh", slug: "fresh")
    inv, = Invitation.issue!(family: fresh, email: "first@example.test", role: "organizer")
    u = make_user(email: "first@example.test", name: "First")
    inv.accept!(u)
    assert fresh.memberships.find_by(user: u).owner?
    inv2, = Invitation.issue!(family: fresh, email: "second@example.test", role: "organizer")
    u2 = make_user(email: "second@example.test", name: "Second")
    inv2.accept!(u2)
    assert_not fresh.memberships.find_by(user: u2).owner?
  end
end
