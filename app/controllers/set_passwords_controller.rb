# Sets a password from an administrator-issued, single-use link.
class SetPasswordsController < ApplicationController
  LINK_VALID_FOR = 7.days
  skip_before_action :authenticate_user!
  layout "application"
  before_action :load_user

  def edit; end

  def update
    dn = params[:name].to_s.squish
    if dn.blank? || dn.length > 60
      flash.now[:alert] = "Choose a display name (up to 60 characters)."
      return render :edit, status: :unprocessable_entity
    end
    @user.name = dn
    if @user.reset_password(params[:password], params[:password_confirmation])
      @user.update_columns(reset_password_token: nil)
      sign_in(@user)
      redirect_to root_path, notice: "Password set."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_user
    @user = User.find_by(reset_password_token: User.set_password_digest(params[:token]))
    if @user.nil? || @user.reset_password_sent_at.nil? || @user.reset_password_sent_at < LINK_VALID_FOR.ago
      render plain: "This link is invalid or has expired. Ask for a new one.", status: :gone
    end
  end
end
