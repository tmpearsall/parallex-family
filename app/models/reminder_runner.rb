# The daily reminder run. For each member who has not opted out it works out what is due today, drops anything
# they were already reminded of (EmailDelivery's unique index is the guarantee), and sends ONE digest.
#
#   RSVP        a household that has not answered, 14, 7, 3, 1 and 0 days before the RSVP-by date
#   Vote        dates are being voted on and the member has not voted: weekly
#   Upcoming    the reunion is 30, 7 or 1 days away
#   Task        something the member claimed and has not finished, reunion within 14 days: weekly
#   Event       a family event is tomorrow
class ReminderRunner
  Item = Struct.new(:kind, :key, :text, :url, :link_label, keyword_init: true) do
    def headline = text
  end

  RSVP_OFFSETS = [ 14, 7, 3, 1, 0 ].freeze
  UPCOMING_OFFSETS = [ 30, 7, 1 ].freeze
  MAX_ITEMS = 12

  def initialize(today: Date.current, mailer: ReminderMailer)
    @today = today
    @mailer = mailer
  end

  # Returns { sent: n (emails), items: n, failed: n }.
  def run
    totals = { sent: 0, items: 0, failed: 0 }
    Membership.where(email_reminders: true).includes(:family, :user, :person).find_each do |m|
      items = due_items(m).first(MAX_ITEMS)
      claimed = claim(m, items)
      next if claimed.empty?
      begin
        @mailer.with(membership: m, items: claimed).digest.deliver_now
        EmailDelivery.where(membership_id: m.id, item_key: claimed.map { |i| key_for(i) }).update_all(status: "sent", updated_at: Time.current)
        totals[:sent] += 1
        totals[:items] += claimed.size
      rescue StandardError => e
        EmailDelivery.where(membership_id: m.id, item_key: claimed.map { |i| key_for(i) }).delete_all   # try again next run
        Rails.logger.error("reminder email failed for membership #{m.id}: #{e.class}: #{e.message}")
        totals[:failed] += 1
      end
    end
    SlackDigest.new(today: @today).run unless Instance.dedicated?
    totals
  end

  # What would be sent to this member today (without sending): used by tests and the organizer's preview.
  def due_items(m)
    fam = m.family
    out = []
    household = m.person&.household
    fam.reunions.includes(:rsvps, :date_options, tasks: :claimed_by).each do |r|
      out.concat(rsvp_items(m, r, household))
      out.concat(vote_items(m, r))
      out.concat(upcoming_items(m, r, household))
      out.concat(task_items(m, r))
    end
    out.concat(event_items(m))
    out
  end

  private

  # Builds an absolute address from the _path helper (the _url helpers keep the /f/<family> prefix even when it is
  # the default). A dedicated instance has no /f/<family> in its addresses, so the family is only passed in
  # multi-tenant mode.
  def url(m, helper, *args, **opts)
    family_opt = Instance.dedicated? ? {} : { family: m.family.slug }
    path = Rails.application.routes.url_helpers.public_send(helper.to_s.sub(/_url\z/, "_path"), *args, **family_opt, **opts)
    "#{url_opts[:protocol] || 'http'}://#{url_opts[:host]}#{path}".sub("://:", "://")
  end

  def url_opts = Rails.application.config.action_mailer.default_url_options.to_h.slice(:host, :protocol)

  def rsvp_items(m, r, household)
    return [] unless r.rsvp_by
    days = (r.rsvp_by - @today).to_i
    return [] unless RSVP_OFFSETS.include?(days)
    answered = household && r.rsvps.any? { |x| x.household_id == household.id }
    return [] if answered
    who = household ? "#{household.name} hasn't answered yet" : "Please answer for your #{m.family.terms.party}"
    when_ = days.zero? ? "today is the last day" : "#{days} #{'day'.pluralize(days)} left"
    [ Item.new(kind: "rsvp", key: "rsvp:#{r.id}:#{days}", text: "#{r.title}: #{who} (#{when_}, by #{r.rsvp_by.strftime('%b %-d')}).",
               url: url(m, :reunion_url, r) + "#answer", link_label: "Answer now") ]
  end

  def vote_items(m, r)
    return [] unless r.starts_on.nil? && r.date_options.any? && r.created_at <= @today.to_time - 2.days
    voted = DateVote.where(user_id: m.user_id, date_option_id: r.date_options.map(&:id)).exists?
    return [] if voted
    [ Item.new(kind: "vote", key: "vote:#{r.id}:#{@today.cwyear}-#{@today.cweek}", text: "#{r.title}: vote on the proposed dates so #{m.family.terms.the_people} can pick one.",
               url: url(m, :reunion_url, r) + "#dates", link_label: "Vote") ]
  end

  def upcoming_items(m, r, household)
    return [] unless r.starts_on
    days = (r.starts_on - @today).to_i
    return [] unless UPCOMING_OFFSETS.include?(days)
    mine = household && r.rsvps.find { |x| x.household_id == household.id }
    return [] if mine&.status == "not_attending"
    where = r.location_name.present? ? " at #{r.location_name}" : ""
    [ Item.new(kind: "upcoming", key: "upcoming:#{r.id}:#{days}", text: "#{r.title} is #{days == 1 ? 'tomorrow' : "in #{days} days"}, #{r.starts_on.strftime('%A, %B %-d')}#{where}.",
               url: url(m, :reunion_url, r), link_label: "See the plan") ]
  end

  def task_items(m, r)
    return [] unless r.starts_on && (0..14).cover?((r.starts_on - @today).to_i)
    r.tasks.select { |t| t.claimed_by_id == m.user_id && !t.done }.map do |t|
      Item.new(kind: "task", key: "task:#{t.id}:#{@today.cwyear}-#{@today.cweek}", text: "You said you'd handle: #{t.title} (#{r.title}, #{r.starts_on.strftime('%b %-d')}).",
               url: url(m, :reunion_url, r) + "#tasks", link_label: "Mark it done")
    end
  end

  def event_items(m)
    day = @today + 1
    m.family.events.visible_to(m).overlapping(day, day).select { |e| e.occurrence_days(day, day).include?(day) }.map do |e|
      Item.new(kind: "event", key: "event:#{e.id}:#{day}", text: "Tomorrow: #{e.title}#{" at #{e.time_note}" if e.time_note}#{" (#{e.location})" if e.location}.",
               url: url(m, :event_url, e), link_label: "Details")
    end
  end

  def key_for(item) = item.key

  # Insert-first: whoever inserts the row owns the send. A row that already exists means "already reminded".
  def claim(m, items)
    items.select do |i|
      EmailDelivery.create!(family_id: m.family_id, membership_id: m.id, kind: i.kind, item_key: i.key, status: "sending")
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
