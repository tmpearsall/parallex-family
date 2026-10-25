# Public: opening an invitation link. A new person makes an account; someone who already has one signs in and
# joins. The link is the credential, so it is one-time and expires.
class InvitationsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load

  def show
    @existing = User.find_by(email: @invitation.email)
    store_location_for(:user, invitation_path(params[:token])) if @existing && !user_signed_in?
  end

  # Signed-in person joins.
  def accept
    return redirect_to(new_user_session_path, alert: "Sign in first.") unless user_signed_in?
    @invitation.accept!(current_user)
    redirect_to family_home_path(family: @invitation.family.slug), notice: "You joined #{@invitation.family.name}."
  end

  # New person: choose a name and password, join, and be signed in.
  def register
    if User.exists?(email: @invitation.email)
      return redirect_to(invitation_path(params[:token]), alert: "That email already has an account. Sign in to join.")
    end
    dn = params[:name].to_s.squish
    user = User.new(email: @invitation.email, name: dn, password: params[:password], password_confirmation: params[:password_confirmation])
    if dn.blank? || dn.length > 60
      flash.now[:alert] = "Choose a display name (up to 60 characters)."
      @existing = nil
      return render :show, status: :unprocessable_entity
    end
    if user.save
      @invitation.accept!(user)
      sign_in(user)
      redirect_to family_home_path(family: @invitation.family.slug), notice: "Welcome to #{@invitation.family.name}."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      @existing = nil
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load
    @invitation = Invitation.find_by_token(params[:token])
    render plain: "This invitation is invalid or has expired. Ask the organizer for a new one.", status: :gone unless @invitation
  end
end
