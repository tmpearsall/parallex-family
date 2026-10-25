# Public: stop reminder emails for one membership. The token is the credential, as in every unsubscribe link.
# GET shows a confirmation page (so mail scanners that open links do not unsubscribe anyone); the POST does it,
# and also answers the one-click List-Unsubscribe header.
class UnsubscribesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection only: :create   # one-click unsubscribe posts without a session or form token
  before_action :load

  def show; end

  def create
    @membership.update_columns(email_reminders: false)
    render :done
  end

  private

  def load
    @membership = Membership.includes(:family).find_by(unsubscribe_token: params[:token])
    render plain: "This link is not valid.", status: :not_found unless @membership
  end
end
