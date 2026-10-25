require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "only the digest of the token is stored and it finds the invitation" do
    inv, raw = Invitation.issue!(family: family, email: "Cousin@Example.test")
    assert_equal "cousin@example.test", inv.email
    assert_not_equal raw, inv.token_digest
    assert_equal inv, Invitation.find_by_token(raw)
    assert_nil Invitation.find_by_token("wrong")
  end

  test "expired and accepted invitations are not found" do
    inv, raw = Invitation.issue!(family: family, email: "a@example.test")
    inv.update_columns(expires_at: 1.minute.ago)
    assert_nil Invitation.find_by_token(raw)
    inv2, raw2 = Invitation.issue!(family: family, email: "b@example.test")
    inv2.accept!(make_user)
    assert_nil Invitation.find_by_token(raw2)
  end

  test "accepting makes a membership with the invited role and person, and is idempotent" do
    p = make_person("Ann")
    inv, = Invitation.issue!(family: family, email: "a@example.test", role: "organizer", person: p)
    u = make_user
    m = inv.accept!(u)
    assert_equal [ "organizer", p.id ], [ m.role, m.person_id ]
    assert_no_difference "Membership.count" do
      Invitation.issue!(family: family, email: "a@example.test").first.accept!(u)
    end
  end

  test "a person from another family cannot be attached" do
    z = make_person("Zed", "Lee", fam: make_family("Lee"))
    assert_raises(ActiveRecord::RecordInvalid) { Invitation.issue!(family: family, email: "a@example.test", person: z) }
  end
end
