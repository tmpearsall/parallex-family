require "test_helper"

class EmailTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @boss = member(role: "organizer", name: "Troy", email: "troy@example.test")
    sign_in @boss
    @f = family.slug
  end

  test "an organizer emails each invitee their own one-time link" do
    assert_emails 2 do
      post members_path(family: @f), params: { invite: { emails: "a@example.test b@example.test", send_email: "1" } }
    end
    assert_response :success
    assert_equal 2, response.body.scan("Emailed").size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "b@example.test" ], mail.to
    assert_equal [ "troy@example.test" ], mail.reply_to
    assert_match(/Troy invited you to Rowe/, mail.subject)
    url = mail.text_part.body.to_s[%r{https?://\S+/invite/[\w-]+}]
    assert url
    assert_no_match(/\?family=/, url)
    assert_equal 2, Invitation.where.not(emailed_at: nil).count
  end

  test "the emailed link works once and joins the family" do
    post members_path(family: @f), params: { invite: { emails: "new@example.test", send_email: "1" } }
    raw = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/invite/([\w-]+)}, 1]
    sign_out :user
    post register_invitation_path(raw), params: { name: "New", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to family_home_path(family: @f)
    get invitation_path(raw)
    assert_response :gone
  end

  test "without 'Email it' ticked nothing is sent but the link is shown" do
    assert_no_emails do
      post members_path(family: @f), params: { invite: { emails: "a@example.test", send_email: "0" } }
    end
    assert_match(%r{/invite/[\w-]+}, response.body)
  end

  test "when email is not set up, nothing is sent and the page says so" do
    override(ApplicationMailer, :configured?, -> { false }) do
      assert_no_emails do
        post members_path(family: @f), params: { invite: { emails: "a@example.test", send_email: "1" } }
      end
      assert_match(/not set up yet/, response.body)
      assert_match(%r{/invite/[\w-]+}, response.body)
    end
  end

  test "a failed send is reported, recorded, and the link is still shown" do
    override(InvitationMailer, :with, ->(**) { raise Net::SMTPAuthenticationError, "bad login" }) do
      post members_path(family: @f), params: { invite: { emails: "a@example.test", send_email: "1" } }
    end
    assert_match(/Email failed/, response.body)
    assert_match(%r{/invite/[\w-]+}, response.body)
    assert Invitation.find_by(email: "a@example.test").email_error.present?
  end

  test "resend withdraws the old link and emails a new one" do
    inv, old_raw = Invitation.issue!(family: family, email: "late@example.test")
    assert_emails 1 do
      post resend_member_path(inv, family: @f)
    end
    assert_not Invitation.exists?(inv.id)
    assert_nil Invitation.find_by_token(old_raw)
    new_raw = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/invite/([\w-]+)}, 1]
    assert Invitation.find_by_token(new_raw)
  end

  test "an organizer cannot resend another family's invitation" do
    lee = make_family("Lee")
    inv, = Invitation.issue!(family: lee, email: "x@example.test")
    post resend_member_path(inv, family: @f)
    assert_response :not_found
    assert Invitation.exists?(inv.id)
  end

  test "a family cannot send more than a day's limit of invitations" do
    MembersController::DAILY_INVITATION_LIMIT.times { |i| Invitation.issue!(family: family, email: "n#{i}@example.test") }
    assert_no_emails do
      post members_path(family: @f), params: { invite: { emails: "one@example.test", send_email: "1" } }
    end
    assert_redirected_to members_path(family: @f)
  end
end

class UnsubscribeTest < ActionDispatch::IntegrationTest
  test "the link asks first, then stops reminders for that membership only; one-click works too" do
    a, b = member, member
    m = a.memberships.first
    token = m.unsubscribe_token!
    get unsubscribe_path(token: token)
    assert_response :success
    assert m.reload.email_reminders, "opening the link does not unsubscribe (mail scanners open links)"
    post unsubscribe_path(token: token)
    assert_not m.reload.email_reminders
    assert b.memberships.first.email_reminders
    m.update_columns(email_reminders: true)
    post unsubscribe_path(token: token), params: { "List-Unsubscribe" => "One-Click" }
    assert_not m.reload.email_reminders
  end

  test "a wrong token is a 404" do
    get unsubscribe_path(token: "nope")
    assert_response :not_found
  end

  test "a member turns their own reminders off and on" do
    u = member
    sign_in u
    patch my_reminders_path(family: family.slug, on: "0")
    assert_not u.memberships.first.reload.email_reminders
    patch my_reminders_path(family: family.slug, on: "1")
    assert u.memberships.first.reload.email_reminders
  end
end
