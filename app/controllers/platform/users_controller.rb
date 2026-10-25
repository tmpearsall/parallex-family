# Password help, for the platform administrator only: a fresh one-time set-password link for an account.
class Platform::UsersController < ApplicationController
  before_action :platform_admin_only!

  def link
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    return redirect_to(platform_families_path, alert: "No account with that email.") unless user
    @user = user
    @url = set_password_url(user.issue_set_password_token!)
  end
end
