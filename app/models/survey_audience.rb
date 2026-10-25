# Who a survey goes to. Returns plain hashes (email, name, person, membership); never anyone who opted out of surveys
# for this family. Members who switched reminders off are skipped too.
module SurveyAudience
  CHOICES = [
    [ "Only the organizers", "organizers" ],
    [ "Everyone with an account", "members" ],
    [ "Everyone on the list who has an email", "listed" ],
    [ "Everyone: accounts and the list", "everyone" ],
    [ "Only people who have not answered yet", "unanswered" ]
  ].freeze

  def self.recipients(survey, audience)
    family = survey.family
    out = {}
    case audience
    when "organizers" then members(family, out, organizers_only: true)
    when "members" then members(family, out)
    when "listed" then listed(family, out)
    when "everyone" then members(family, out); listed(family, out)
    when "unanswered"
      survey.recipients.includes(:response, :person, :membership).reject(&:responded?).each do |r|
        out[r.email] = { email: r.email, name: r.name, person: r.person, membership: r.membership }
      end
    end
    blocked = family.survey_opt_outs.pluck(:email).to_set
    out.values.reject { |h| blocked.include?(h[:email]) }.sort_by { |h| h[:name].to_s.downcase }
  end

  def self.members(family, out, organizers_only: false)
    scope = family.memberships.where(email_reminders: true)
    scope = scope.where(role: "organizer") if organizers_only
    scope.includes(:user, :person).each do |m|
      email = m.user.email.to_s.downcase
      out[email] ||= { email: email, name: m.user.label, person: m.person, membership: m }
    end
  end

  def self.listed(family, out)
    family.people.where.not(email: nil).each do |p|
      email = p.email.to_s.downcase
      out[email] ||= { email: email, name: p.display_name, person: p, membership: nil }
    end
  end
end
