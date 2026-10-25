require "test_helper"

class SlackTest < ActionDispatch::IntegrationTest
  PW = "Str0ng!Pass#1".freeze
  HOOK = "https://hooks.slack.com/services/T0000000/B0000000/abcdefghijklmnopqrstuvwx".freeze

  setup do
    @sent = []
    SlackNotifier.transport = ->(url, json) { @sent << [ url, JSON.parse(json) ]; true }
    @fam = Family.create!(name: "Slack Org", slug: "slack-org", kind: "group")
    @owner = mk("owner@example.test", "organizer", "Owner", true)
    @org = mk("org@example.test", "organizer", "Org", false)
    @mem = mk("mem@example.test", "member", "Mem", false)
  end

  teardown { SlackNotifier.transport = nil }

  def mk(email, role, name, owner)
    u = User.create!(email: email, password: PW, name: name)
    Membership.create!(family: @fam, user: u, role: role, owner: owner)
    u
  end

  def sign_in(u) = post(user_session_path, params: { user: { email: u.email, password: PW } })

  def connect(**flags)
    i = @fam.build_slack_integration(**flags)
    i.webhook_url = HOOK
    i.save!
    i
  end

  test "only Slack's own address is accepted, and it is stored encrypted" do
    assert SlackIntegration.valid_webhook?(HOOK)
    assert_not SlackIntegration.valid_webhook?("https://evil.example/services/T0000000/B0000000/abcdefghijklmnopqrstuvwx")
    assert_not SlackIntegration.valid_webhook?("http://hooks.slack.com/services/T0000000/B0000000/abcdefghijklmnopqrstuvwx")
    assert_not SlackIntegration.valid_webhook?("https://hooks.slack.com.evil.test/services/T0000000/B0000000/abcdefghijklmnopqrstuvwx")
    i = connect
    assert_not_includes i.reload.webhook_ciphertext, "hooks.slack.com"
    assert_equal HOOK, i.webhook_url
  end

  test "the owner connects Slack, an organizer who is not the owner cannot, a member sees nothing" do
    sign_in @owner
    patch slack_path(family: @fam.slug), params: { slack: { webhook_url: "https://evil.example/x" } }
    assert_nil @fam.reload.slack_integration
    patch slack_path(family: @fam.slug), params: { slack: { webhook_url: HOOK, notify_meetings: "1", notify_forum: "0" } }
    assert @fam.reload.slack_integration
    assert @fam.slack_integration.notify_meetings
    assert_not @fam.slack_integration.notify_forum
    delete destroy_user_session_path
    sign_in @org
    patch slack_path(family: @fam.slug), params: { slack: { webhook_url: HOOK.sub("T0000000", "T1111111") } }
    assert_equal HOOK, @fam.reload.slack_integration.webhook_url
    get slack_path(family: @fam.slug)
    assert_response :success
    assert_not_includes response.body, "hooks.slack.com/services/T"
    delete destroy_user_session_path
    sign_in @mem
    get slack_path(family: @fam.slug)
    assert_response :forbidden
  end

  test "the page never shows the saved address" do
    connect
    sign_in @owner
    get slack_path(family: @fam.slug)
    assert_includes response.body, "Connected"
    assert_not_includes response.body, "abcdefghijklmnopqrstuvwx"
  end

  test "the test button posts, and disconnect deletes the address" do
    connect
    sign_in @owner
    post test_slack_path(family: @fam.slug)
    assert_equal 1, @sent.size
    assert_match(/Slack is connected/, @sent.first.last["text"])
    delete slack_path(family: @fam.slug)
    assert_nil @fam.reload.slack_integration
  end

  test "a new forum topic is posted with title and author only, and escaped" do
    connect
    sign_in @mem
    post board_path(family: @fam.slug), params: { board_post: { title: "Budget <b>& dates", body: "Secret details 555-0100" } }
    assert_equal 1, @sent.size
    text = @sent.first.last["text"]
    assert_includes text, "Mem"
    assert_includes text, "Budget &lt;b&gt;&amp; dates"
    assert_not_includes text, "Secret details"
    assert_not_includes text, "555-0100"
  end

  test "a switched-off kind posts nothing" do
    connect(notify_forum: false)
    sign_in @mem
    post board_path(family: @fam.slug), params: { board_post: { title: "Quiet topic", body: "x" } }
    assert_empty @sent
  end

  test "the daily run posts tomorrow's organizers' meeting once, and never a members' event" do
    connect
    @fam.events.create!(title: "Reunion prep", starts_on: Date.current + 1, organizers_only: true, time_note: "7 pm")
    @fam.events.create!(title: "Open cookout", starts_on: Date.current + 1)
    assert_equal 1, SlackDigest.new(today: Date.current).run
    assert_match(/Reunion prep/, @sent.first.last["text"])
    assert_equal 0, SlackDigest.new(today: Date.current).run, "posted once"
    assert_equal 1, @sent.size
  end

  test "RSVP deadlines and closing surveys are posted when those switches are on" do
    connect
    r = @fam.reunions.create!(title: "Picnic", rsvp_by: Date.current + 3)
    s = @fam.surveys.create!(title: "Dates?", created_by: @owner, status: "open", closes_on: Date.current + 1)
    s.questions.create!(kind: "short", prompt: "Q")
    SlackDigest.new(today: Date.current).run
    texts = @sent.map { |_, j| j["text"] }
    assert texts.any? { |t| t.include?("RSVP deadline in 3 days") && t.include?("Picnic") }
    assert texts.any? { |t| t.include?("Survey closes tomorrow") && t.include?("Dates?") }
  end

  test "nothing is sent when Slack is not connected, and a failed post never raises" do
    sign_in @mem
    post board_path(family: @fam.slug), params: { board_post: { title: "No slack", body: "x" } }
    assert_empty @sent
    connect
    SlackNotifier.transport = ->(_u, _j) { raise Timeout::Error }
    assert_equal false, SlackNotifier.post(@fam, "forum", "hello")
    assert_equal "failed", @fam.slack_integration.reload.last_status
  end

  test "the Admin page links Slack on the commercial site" do
    sign_in @owner
    get admin_path(family: @fam.slug)
    assert_includes response.body, "/f/slack-org/slack"
  end
end
