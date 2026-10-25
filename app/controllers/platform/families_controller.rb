# Support area for the platform administrator: create a family and its first organizer's invitation, and see
# counts. It shows no family's people, reunions or forum.
class Platform::FamiliesController < ApplicationController
  before_action :platform_admin_only!

  def index
    @families = Family.order(:name).left_joins(:memberships).group("families.id").select("families.*, count(memberships.id) as member_count")
  end

  def create
    family = Family.new(params.require(:family).permit(:name, :slug, :kind))
    email = params.dig(:family, :organizer_email).to_s.strip.downcase
    unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
      return redirect_to(platform_families_path, alert: "Enter the organizer's email.")
    end
    Family.transaction do
      family.created_by_id = current_user.id
      family.save!
      _, raw = Invitation.issue!(family: family, email: email, role: "organizer", invited_by: current_user)
      @family, @email, @url = family, email, invitation_url(raw)
    end
    render :created
  rescue ActiveRecord::RecordInvalid => e
    redirect_to platform_families_path, alert: e.record.errors.full_messages.to_sentence
  end
end
