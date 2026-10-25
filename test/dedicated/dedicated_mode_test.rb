require "test_helper"

# Run with:  INSTANCE_MODE=dedicated DEDICATED_FAMILY_SLUG=rowe bin/rails test test/dedicated
# (Routes are built at boot, so this mode needs its own test run; the normal run skips these.)
class DedicatedModeTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    skip "dedicated-mode test run only" unless Instance.dedicated? && Instance.family_slug == "rowe"
    family   # slug "rowe"
  end

  test "the family lives at the site root, with no /f/ in any address" do
    u = member(name: "Thea")
    sign_in u
    get "/"
    assert_response :success
    assert_match(/Thea|Rowe/, response.body)
    assert_no_match(%r{/f/rowe}, response.body)
    assert_match(%r{href="/tree"}, response.body)
    %w[/tree /people /households /reunions /calendar /forum /directory].each do |path|
      get path
      assert_response :success, path
      assert_no_match(%r{/f/rowe}, response.body, path)
    end
  end

  test "the long address still works for members" do
    sign_in member
    get "/f/rowe/people"
    assert_response :success
  end

  test "signed-out visitors go to sign in, and non-members get a 404" do
    get "/"
    assert_redirected_to new_user_session_path
    sign_in make_user
    get "/"          # a first successful request would establish the session; this one is the real check
    assert_response :not_found
  end

  test "there is no platform area and no family picker" do
    sign_in make_user(platform_admin: true)
    get "/platform/families"
    assert_response :not_found
    assert_not Rails.application.routes.named_routes.key?(:platform_families)
  end

  test "a platform administrator who is a member sees the site without errors" do
    sign_in member(platform_admin: true)
    get "/"
    assert_response :success
    assert_no_match(/Platform|Switch family/, response.body)
  end

  test "another family's slug is not reachable" do
    make_family("Lee")
    sign_in member
    get "/f/rowe/people"
    assert_response :success
    get "/f/lee/people"
    assert_response :not_found
  end

  test "an invitation sends the new member to the root, and the emailed link has no /f/" do
    boss = member(role: "organizer", name: "Troy")
    sign_in boss
    assert_emails 1 do
      post "/members", params: { invite: { emails: "new@example.test", send_email: "1" } }
    end
    mail = ActionMailer::Base.deliveries.last
    link = mail.text_part.body.to_s[%r{https?://\S+/invite/[\w-]+}]
    assert link
    assert_no_match(%r{/f/}, link)
    sign_out :user
    raw = link[%r{/invite/([\w-]+)}, 1]
    post register_invitation_path(raw), params: { name: "New", password: "Abcdef1!xyz", password_confirmation: "Abcdef1!xyz" }
    assert_redirected_to "/"
  end

  test "reminder emails link to short addresses" do
    m = member(person: make_person("Ann", household: Household.create!(family: family, name: "The Rowes"))).memberships.first
    Reunion.create!(family: family, title: "Rowe reunion", starts_on: "2027-07-02", rsvp_by: "2027-06-01")
    ActionMailer::Base.deliveries.clear
    ReminderRunner.new(today: Date.parse("2027-05-25")).run
    body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    assert_match(%r{https?://[^/\s]+/reunions/\d+#answer}, body)
    assert_no_match(%r{/f/rowe}, body)
  end

  test "the calendar feed address is unchanged" do
    m = member.memberships.first
    token = m.calendar_token!
    get "/calendar/#{token}.ics"
    assert_response :success
    assert_match(/BEGIN:VCALENDAR/, response.body)
  end

  test "mail on a dedicated site comes from the family's own name and never says Parallex" do
    f = family
    u = User.create!(email: "thea-#{SecureRandom.hex(3)}@example.test", password: "Str0ng!Pass#1", name: "Thea")
    f.memberships.create!(user: u, role: "organizer")
    inv, = Invitation.issue!(family: f, email: "c@example.test", role: "member", invited_by: u)
    mail = InvitationMailer.with(invitation: inv, url: "https://x/invite/y", inviter: u).invite
    assert_includes mail.header["From"].to_s, f.name
    assert_no_match(/parallex family/i, mail.header["From"].to_s)
    text = mail.text_part&.body.to_s + mail.body.to_s
    assert_no_match(/parallex family/i, text)
  end

  test "the sign-in page and its title carry the family's own name, not a generic word" do
    f = family
    get "/users/sign_in"
    assert_response :success
    assert_includes response.body, "<title>Sign in · #{f.name}</title>"
    assert_includes response.body, ">#{f.name}</a>"
  end

  test "a visit on another address is sent to the family's own address, but the health check is not" do
    ENV["MAIL_HOST"] = "www.example.test"
    get "/people"
    assert_response :moved_permanently
    assert_equal "https://www.example.test/people", response.headers["Location"]
    get "/up"
    assert_response :success
  ensure
    ENV.delete("MAIL_HOST")
  end
end
