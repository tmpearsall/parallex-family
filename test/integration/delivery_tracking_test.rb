require "test_helper"
require "openssl"
require "base64"

class DeliveryTrackingTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  PW = "Str0ng!Pass#1".freeze
  SECRET_RAW = "super-secret-signing-key-0123456789".freeze
  SECRET = "whsec_#{Base64.strict_encode64(SECRET_RAW)}".freeze

  setup do
    ENV["RESEND_WEBHOOK_SECRET"] = SECRET
    ActionMailer::Base.deliveries.clear
    @fam = Family.create!(name: "Track Org", slug: "track-org", kind: "group")
    @owner = mk("owner@example.test", "organizer", "Owner", true)
    @mem = mk("mem@example.test", "member", "Mem", false)
  end

  teardown { ENV.delete("RESEND_WEBHOOK_SECRET") }

  def mk(email, role, name, owner)
    u = User.create!(email: email, password: PW, name: name)
    Membership.create!(family: @fam, user: u, role: role, owner: owner)
    u
  end

  def sign_in(u) = post(user_session_path, params: { user: { email: u.email, password: PW } })

  def signed_post(payload, secret: SECRET, id: "msg_1", ts: Time.current.to_i)
    body = payload.to_json
    key = Base64.decode64(secret.sub("whsec_", ""))
    sig = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, "#{id}.#{ts}.#{body}"))
    post "/webhooks/resend", params: body, headers: { "CONTENT_TYPE" => "application/json", "svix-id" => id, "svix-timestamp" => ts.to_s, "svix-signature" => "v1,#{sig}" }
  end

  def send_one(to, subject = "Hello")
    EmailLog.create!(family: @fam, kind: "announcement_mailer.note", to_email: to, subject: subject, status: "accepted")
  end

  test "an outgoing message is logged with its family and kind, and the internal markers never leave" do
    u = User.create!(email: "x@example.test", password: PW, name: "X")
    TestMailer.with(user: u, family: @fam).hello.deliver_now
    log = EmailLog.find_by!(to_email: "x@example.test")
    assert_equal @fam.id, log.family_id
    assert_equal "test_mailer.hello", log.kind
    assert_equal "accepted", log.status
    mail = ActionMailer::Base.deliveries.last
    assert_nil mail.header["X-Parallex-Family"]
    assert_nil mail.header["X-Parallex-Kind"]
  end

  test "a signed bounce marks the message bounced; a delivered report marks delivered" do
    log = send_one("mem@example.test")
    signed_post({ type: "email.bounced", data: { to: [ "mem@example.test" ], bounce: { message: "mailbox full" } } })
    assert_response :ok
    assert_equal "bounced", log.reload.status
    assert_equal "mailbox full", log.detail
    other = send_one("owner@example.test")
    signed_post({ type: "email.delivered", data: { to: [ "owner@example.test" ] } }, id: "msg_2")
    assert_equal "delivered", other.reload.status
  end

  test "a request with a wrong signature, an old timestamp or no secret changes nothing" do
    log = send_one("mem@example.test")
    signed_post({ type: "email.bounced", data: { to: [ "mem@example.test" ] } }, secret: "whsec_#{Base64.strict_encode64('another-secret-key-entirely-here')}")
    assert_response :unauthorized
    signed_post({ type: "email.bounced", data: { to: [ "mem@example.test" ] } }, ts: Time.current.to_i - 3600)
    assert_response :unauthorized
    post "/webhooks/resend", params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
    assert_equal "accepted", log.reload.status
    ENV.delete("RESEND_WEBHOOK_SECRET")
    signed_post({ type: "email.bounced", data: { to: [ "mem@example.test" ] } })
    assert_response :service_unavailable
    assert_equal "accepted", log.reload.status
  end

  test "an unknown event type or an address never emailed is accepted and ignored" do
    signed_post({ type: "email.opened", data: { to: [ "mem@example.test" ] } })
    assert_response :ok
    signed_post({ type: "email.bounced", data: { to: [ "stranger@example.test" ] } }, id: "msg_3")
    assert_response :ok
    assert_equal 0, EmailLog.where(status: "bounced").count
  end

  test "latest status per address uses the newest message" do
    old = send_one("mem@example.test")
    old.update_columns(status: "bounced", created_at: 2.days.ago)
    send_one("mem@example.test").update!(status: "delivered")
    assert_equal "delivered", EmailLog.latest_statuses([ "MEM@example.test" ])["mem@example.test"]
  end

  test "organizers see a bounced address on Access and on Needs a call, with the phone number" do
    p = @fam.people.create!(first_name: "Bounce", last_name: "Back", email: "bounce@example.test", phone: "555-0123")
    @fam.people.create!(first_name: "No", last_name: "Mail", phone: "555-0199")
    send_one("bounce@example.test").update!(status: "bounced")
    send_one("mem@example.test").update!(status: "bounced")
    sign_in @owner
    get members_path(family: @fam.slug)
    assert_includes response.body, "email bounced"
    get needs_a_call_path(family: @fam.slug)
    assert_response :success
    assert_includes response.body, "Bounce Back"
    assert_includes response.body, "555-0123"
    assert_includes response.body, "No Mail"
    assert_includes response.body, "555-0199"
    get admin_path(family: @fam.slug)
    assert_includes response.body, "Needs a call"
    assert_not_includes p.email.to_s, "<"
  end

  test "the needs-a-call page lists survey non-answers whose email is not delivered, and is organizers only" do
    s = @fam.surveys.create!(title: "Dates?", created_by: @owner, status: "open")
    s.questions.create!(kind: "short", prompt: "Q")
    r = s.recipients.create!(email: "mem@example.test", name: "Mem Person", token_digest: SurveyRecipient.digest("a" * 24), sent_at: 3.days.ago)
    send_one("mem@example.test").update!(status: "bounced")
    sign_in @owner
    get needs_a_call_path(family: @fam.slug)
    assert_includes response.body, "Survey: Dates?"
    assert_includes response.body, "Mem Person"
    assert_includes response.body, "bounced"
    delete destroy_user_session_path
    sign_in @mem
    get needs_a_call_path(family: @fam.slug)
    assert_response :forbidden
  end

  test "old log entries are purged" do
    send_one("mem@example.test").update_columns(created_at: 100.days.ago)
    send_one("owner@example.test")
    EmailLog.purge_old!
    assert_equal 1, EmailLog.count
  end
end
