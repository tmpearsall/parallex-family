class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  allow_browser versions: :modern

  # A private family site: never indexed.
  after_action { response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive") }

  private

  def admin_only!
    head :forbidden unless current_user.admin?
  end
end
