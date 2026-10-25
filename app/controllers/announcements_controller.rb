# An organizer writes a message and sends it to everyone, to households that have not answered an RSVP, or to
# people with an unfinished task. The first step previews who would get it; nothing is sent until it is confirmed.
class AnnouncementsController < TenantController
  before_action :organizer_only!

  def index
    @announcements = current_family.announcements.includes(:user).order(created_at: :desc).limit(30)
  end

  def new
    @announcement = current_family.announcements.new
  end

  def create
    @announcement = current_family.announcements.new(announcement_params.merge(user: current_user))
    @reunion = current_family.reunions.find_by(id: @announcement.reunion_id)
    return render(:new, status: :unprocessable_entity) unless @announcement.valid?
    @recipients = Announcement.recipients(current_family, @announcement.audience, @reunion)
    return redirect_to(new_announcement_path, alert: "No one would receive that. Everyone in it has reminders off, or the audience is empty.") if @recipients.empty?
    room = Announcement::DAILY_LIMIT - Announcement.sent_today(current_family)
    if @recipients.size > room
      return redirect_to(new_announcement_path, alert: "That would be #{@recipients.size} emails and only #{[ room, 0 ].max} are left for today (the limit is #{Announcement::DAILY_LIMIT} a day).")
    end
    return render(:preview) unless params[:confirm] == "1"

    failed = 0
    @recipients.each do |m|
      AnnouncementMailer.with(membership: m, announcement: @announcement).note.deliver_now
    rescue StandardError => e
      Rails.logger.error("announcement email failed for membership #{m.id}: #{e.class}: #{e.message}")
      failed += 1
    end
    @announcement.recipient_count = @recipients.size - failed
    @announcement.failed_count = failed
    @announcement.save!
    notice = "Sent to #{@announcement.recipient_count} #{'person'.pluralize(@announcement.recipient_count)}."
    notice += " #{failed} failed; check the Email section on the Access page." if failed.positive?
    redirect_to announcements_path, notice: notice
  end

  private

  def announcement_params = params.require(:announcement).permit(:audience, :reunion_id, :subject, :body)
end
