# One personal link to one survey. Carries a "don't send me surveys" link and the one-click header.
class SurveyMailer < ApplicationMailer
  # params: recipient (SurveyRecipient), token (the raw personal token, never stored), reminder (bool)
  def invite
    @recipient = params[:recipient]
    @url = survey_answer_url(token: params[:token])
    @survey = @recipient.survey
    @family = @survey.family
    @sender = @survey.created_by.label
    @sender = "An organizer" if @sender.casecmp?(@family.name) || @sender == "A member"
    @stop_url = survey_stop_url(token: params[:token])
    headers["List-Unsubscribe"] = "<#{@stop_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    prefix = params[:reminder] ? "Reminder: " : ""
    mail(from: from_for(@family), to: @recipient.email, reply_to: @survey.created_by.email, subject: "#{prefix}#{@survey.title}")
  end
end
