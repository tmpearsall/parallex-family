class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  allow_browser versions: :modern

  # A private family site: never indexed.
  after_action { response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive") }

  helper_method :current_membership, :current_family, :organizer?

  # Inside a family, every URL helper fills in /f/:family from the current family, so positional arguments are
  # the record ids (person_path(person)).
  def default_url_options = Current.membership ? { family: Current.family.slug } : {}

  private

  def current_membership = Current.membership
  def current_family = Current.family
  def organizer? = current_membership&.organizer?

  def platform_admin_only!
    head :forbidden unless current_user.platform_admin?
  end
end
