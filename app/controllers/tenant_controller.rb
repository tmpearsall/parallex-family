# Everything inside /f/:family. The family is found only through the signed-in user's own memberships, so a
# family the user does not belong to is a 404 and nothing in it can be reached by guessing ids.
class TenantController < ApplicationController
  before_action :set_membership

  private

  # The family tree, relationships, birthdays and anniversaries exist only in family workspaces.
  def require_tree!
    head :not_found unless current_family.terms.tree?
  end

  def set_membership
    Current.membership = current_user.memberships.joins(:family).includes(:family).find_by!(families: { slug: params[:family] })
  end

  def organizer_only!
    head :forbidden unless organizer?
  end
end
