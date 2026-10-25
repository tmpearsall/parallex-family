require "test_helper"

class PlatformOperatorTest < ActiveSupport::TestCase
  setup do
    @fam = Family.create!(name: "Customer Org", slug: "customer-org", kind: "group")
    @operator = User.create!(email: "operator@example.test", password: "Str0ng!Pass#1", name: "Operator", platform_admin: true)
  end

  test "the platform administrator cannot be an organizer or owner of a customer's group" do
    assert_not Membership.new(family: @fam, user: @operator, role: "organizer").valid?
    assert_not Membership.new(family: @fam, user: @operator, role: "member", owner: true).valid?
    assert_includes Membership.new(family: @fam, user: @operator, role: "organizer").tap(&:valid?).errors.full_messages.to_sentence, "platform administrator"
  end

  test "the platform administrator can be a plain member if invited for support" do
    assert Membership.new(family: @fam, user: @operator, role: "member").valid?
  end

  test "an invitation for the platform administrator as organizer is refused, as a member it is fine" do
    assert_raises(ActiveRecord::RecordInvalid) { Invitation.issue!(family: @fam, email: "operator@example.test", role: "organizer") }
    assert Invitation.issue!(family: @fam, email: "operator@example.test", role: "member")
  end

  test "an ordinary person can still be the first organizer and owner" do
    u = User.create!(email: "customer@example.test", password: "Str0ng!Pass#1", name: "Customer")
    inv, = Invitation.issue!(family: @fam, email: "customer@example.test", role: "organizer")
    m = inv.accept!(u)
    assert m.organizer?
    assert m.owner?
  end
end
