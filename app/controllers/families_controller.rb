# "/" : the families this account belongs to.
class FamiliesController < ApplicationController
  def index
    @memberships = current_user.memberships.includes(:family).joins(:family).order("families.name")
    redirect_to family_home_path(family: @memberships.first.family.slug) if @memberships.size == 1 && !current_user.platform_admin?
  end
end
