# The people the site is not reaching, for an organizer to phone or text by hand: an email that bounced or was
# reported as spam, no email on file, reminders switched off, and for each open survey the people who have not
# answered and whose email is not confirmed delivered. Organizers only. Nothing is sent from here.
class NeedsCallsController < TenantController
  before_action :organizer_only!

  def show
    @people = current_family.people.by_name.to_a
    emails = @people.map(&:email).compact
    @status = EmailLog.latest_statuses(emails)
    living = @people.select(&:living?)
    @bouncing = living.select { |p| p.email.present? && EmailLog::PROBLEM.include?(@status[p.email.downcase]) }
    @no_email = living.select { |p| p.email.blank? }
    @reminders_off = current_family.memberships.where(email_reminders: false).includes(:user, :person).to_a
    @surveys = current_family.surveys.where(status: "open").includes(:recipients).order(:created_at).map do |s|
      stat = EmailLog.latest_statuses(s.recipients.map(&:email))
      pending = s.recipients.includes(:response, :person).reject(&:responded?).map { |r| [ r, stat[r.email] ] }
      [ s, pending.reject { |_, st| st == "delivered" && r_recent?(s) } ]
    end
  end

  private

  # A survey only just sent has had no time to be answered; hide delivered-but-unanswered people for a day.
  def r_recent?(survey) = survey.recipients.maximum(:sent_at).to_i > 24.hours.ago.to_i
end
