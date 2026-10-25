require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  PW = "Str0ng!Pass#1".freeze

  def organizer(family, name)
    u = User.create!(email: "o-#{SecureRandom.hex(3)}@example.test", password: PW, name: name)
    family.memberships.create!(user: u, role: "organizer")
    u
  end

  def invite(family, inviter, role: "member", person: nil)
    inv, raw = Invitation.issue!(family: family, email: "cousin@example.test", role: role, person: person, invited_by: inviter)
    InvitationMailer.with(invitation: inv, url: "https://www.uptonfam.org/invite/#{raw}", inviter: inviter).invite
  end

  def text_of(mail) = (mail.text_part&.body || mail.body).to_s

  test "it names who invited, who organizes, the plan and the role, and says nothing about the platform" do
    family = Family.create!(name: "Upton Family")
    thea = organizer(family, "Thea")
    family.reunions.create!(title: "Upton Reunion 2027", starts_on: Date.new(2027, 7, 10), location_name: "Cape May")
    mail = invite(family, thea, role: "organizer")
    assert_equal "Thea invited you to Upton Family", mail.subject
    [ text_of(mail), mail.html_part&.body.to_s ].reject(&:empty?).each do |b|
      assert_includes b, "Organized by"
      assert_includes b, "Thea"
      assert_includes b, "Upton Reunion 2027"
      assert_includes b, "an organizer"
      assert_no_match(/parallex/i, b)
    end
    assert_equal [ thea.email ], mail.reply_to
  end

  test "an account named after the site is shown as an organizer, not repeated" do
    family = Family.create!(name: "Upton Family")
    mail = invite(family, organizer(family, "Upton Family"))
    assert_equal "An organizer invited you to Upton Family", mail.subject
    assert_no_match(/Upton Family invited you to Upton Family/, text_of(mail))
  end

  test "a linked person is greeted by first name" do
    family = Family.create!(name: "Greet Family")
    kid = family.people.create!(first_name: "Hawthorne")
    mail = invite(family, organizer(family, "Thea"), person: kid)
    assert_includes text_of(mail), "Hi Hawthorne,"
  end
end
