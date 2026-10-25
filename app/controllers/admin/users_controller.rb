# The administrator invites family members. No email is sent: the one-time set-password link is shown once, here,
# and the administrator hands it over.
class Admin::UsersController < ApplicationController
  before_action :admin_only!

  def index
    @users = User.includes(:person).order(:email)
    @people = Person.where.not(id: User.select(:person_id).where.not(person_id: nil)).by_name
  end

  def create
    email = params.dig(:user, :email).to_s.strip.downcase
    user = User.find_or_initialize_by(email: email)
    user.name = params.dig(:user, :name) if params.dig(:user, :name).present?
    user.person_id = params.dig(:user, :person_id).presence
    user.password = "#{SecureRandom.base58(30)}aZ9!" if user.new_record?
    if user.save
      show_link(user)
    else
      redirect_to admin_users_path, alert: user.errors.full_messages.to_sentence
    end
  end

  def link
    show_link(User.find(params[:id]))
  end

  private

  def show_link(user)
    token = user.issue_set_password_token!
    @user = user
    @url = set_password_url(token)
    render :link
  end
end
