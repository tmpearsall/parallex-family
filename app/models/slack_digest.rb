# The daily Slack run, alongside the email reminders: tomorrow's organizers' meetings, RSVP deadlines coming up,
# and surveys closing tomorrow. Each item is posted once (slack_posts has a unique key).
class SlackDigest
  RSVP_OFFSETS = [ 3, 1 ].freeze

  def initialize(today: Date.current)
    @today = today
  end

  def run
    posted = 0
    SlackIntegration.includes(:family).find_each do |integ|
      f = integ.family
      next if Instance.dedicated?
      items(f).each do |kind, key, text|
        next unless SlackNotifier.enabled_for?(f, kind) && claim(f, key)
        posted += 1 if SlackNotifier.post(f, kind, text)
      end
    end
    posted
  end

  private

  def items(f)
    out = []
    day = @today + 1
    f.events.where(organizers_only: true).overlapping(day, day).select { |e| e.occurrence_days(day, day).include?(day) }.each do |e|
      when_ = [ "tomorrow", e.time_note ].compact.join(", ")
      where = e.location.present? ? " (#{SlackNotifier.esc(e.location)})" : ""
      out << [ "meetings", "meeting:#{e.id}:#{day}", "Meeting #{when_}: <#{SlackNotifier.link(Rails.application.routes.url_helpers.event_path(e, family: f.slug))}|#{SlackNotifier.esc(e.title)}>#{where}" ]
    end
    f.reunions.where(rsvp_by: RSVP_OFFSETS.map { |d| @today + d }).includes(:rsvps).each do |r|
      days = (r.rsvp_by - @today).to_i
      answered = r.rsvps.map(&:household_id).uniq.size
      total = f.households.count
      out << [ "deadlines", "rsvp:#{r.id}:#{days}", "RSVP deadline in #{days} #{'day'.pluralize(days)} for <#{SlackNotifier.link(Rails.application.routes.url_helpers.reunion_path(r, family: f.slug))}|#{SlackNotifier.esc(r.title)}>: #{answered} of #{total} #{f.terms.parties} have answered." ]
    end
    f.surveys.where(status: "open", closes_on: @today + 1).each do |s|
      out << [ "surveys", "survey:#{s.id}:closing", "Survey closes tomorrow: <#{SlackNotifier.link(Rails.application.routes.url_helpers.survey_path(s, family: f.slug))}|#{SlackNotifier.esc(s.title)}>, #{s.response_count} of #{s.recipients.count} have answered." ]
    end
    out
  end

  def claim(family, key)
    SlackPost.create!(family: family, item_key: key)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
