# "Stop sending me surveys" from the link in a survey email. GET asks; POST does it (mail scanners that open links
# do not opt anyone out).
class SurveyStopsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection only: :create
  before_action :load

  def show; end

  def create
    SurveyOptOut.find_or_create_by!(family: @family, email: @recipient.email)
    render :done
  end

  private

  def load
    @recipient = SurveyRecipient.find_by_token(params[:token])
    return render(plain: "This link is not valid.", status: :not_found) unless @recipient
    @family = @recipient.survey.family
  end
end
