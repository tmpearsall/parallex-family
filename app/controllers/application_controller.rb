class ApplicationController < ActionController::Base
  before_action :use_canonical_host
  before_action :authenticate_user!
  allow_browser versions: :modern

  # A private family site: never indexed.
  after_action { response.set_header("X-Robots-Tag", indexable? ? "index, follow" : "noindex, nofollow, noarchive") }

  helper_method :indexable?, :current_membership, :current_family, :organizer?, :owner?, :terms

  # Inside a family, every URL helper fills in /f/:family from the current family, so positional arguments are
  # the record ids (person_path(person)).
  def default_url_options = Current.membership ? { family: Current.family.slug } : {}

  private

  # A dedicated family site answers on one address. Anyone who arrives on another (the old onrender.com link in an
  # early email) is sent to it, so there is one address to remember. Only when MAIL_HOST names that address.
  def use_canonical_host
    canonical = ENV["MAIL_HOST"].to_s.strip
    return unless Instance.dedicated? && canonical.present? && request.get? && request.host != canonical && request.path != "/up"
    redirect_to "https://#{canonical}#{request.fullpath}", status: :moved_permanently, allow_other_host: true
  end

  def indexable? = false

  def current_membership = Current.membership
  def current_family = Current.family
  def organizer? = current_membership&.organizer?
  def owner? = current_membership&.owner?
  def terms = current_family&.terms || Terms.default

  def platform_admin_only!
    head :forbidden unless current_user.platform_admin?
  end
end
