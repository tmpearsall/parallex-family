# Mailing a survey: choose who, preview exactly who gets it, then confirm. The same screen is used to remind people
# who have not answered (that issues them a fresh link; the old one stops working).
class SurveySendsController < TenantController
  before_action :organizer_only!
  before_action :load_survey

  def new
    @audience = @survey.sent_count.positive? ? "unanswered" : "members"
  end

  def create
    @audience = SurveyAudience::CHOICES.map(&:last).include?(params[:audience]) ? params[:audience] : "members"
    return redirect_to(survey_path(@survey), alert: "That survey has no questions yet.") if @survey.questions.empty?
    return redirect_to(survey_path(@survey), alert: "That survey is closed. Open it again first.") if @survey.closed?
    @recipients = SurveyAudience.recipients(@survey, @audience)
    return redirect_to(new_survey_send_path(@survey), alert: "No one would receive that: no emails on file, or everyone is opted out or has answered.") if @recipients.empty?
    room = EmailBudget.left(current_family)
    if @recipients.size > room
      return redirect_to(new_survey_send_path(@survey), alert: "That would be #{@recipients.size} emails and only #{room} are left for today (the limit is #{EmailBudget::DAILY_LIMIT} a day for reminders and surveys together).")
    end
    return render(:preview) unless params[:confirm] == "1"

    sent = failed = 0
    reminder = @audience == "unanswered"
    @survey.update!(status: "open") if @survey.draft?
    @recipients.each do |h|
      rec = @survey.recipients.find_or_initialize_by(email: h[:email])
      rec.assign_attributes(name: h[:name], person: h[:person], membership: h[:membership])
      rec.token_digest = SurveyRecipient.digest(SecureRandom.hex(8)) if rec.new_record?
      rec.save!
      raw = rec.issue_token!
      begin
        SurveyMailer.with(recipient: rec, token: raw, reminder: reminder && rec.sent_at.present?).invite.deliver_now
        reminder && rec.sent_at.present? ? rec.update!(reminded_at: Time.current) : rec.update!(sent_at: Time.current)
        sent += 1
      rescue StandardError => e
        Rails.logger.error("survey email failed for recipient #{rec.id}: #{e.class}: #{e.message}")
        failed += 1
      end
    end
    notice = "Sent to #{sent} #{'person'.pluralize(sent)}."
    notice += " #{failed} failed; check the Email section on the Access page." if failed.positive?
    redirect_to survey_path(@survey), notice: notice
  end

  private

  def load_survey = @survey = current_family.surveys.find(params[:survey_id])
end
