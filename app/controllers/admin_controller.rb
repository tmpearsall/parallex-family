# One place for the people who organize: everything an organizer can do beyond what a member can, gathered on a
# single page. Organizers only.
class AdminController < TenantController
  before_action :organizer_only!

  def show
    @open_surveys = current_family.surveys.where(status: "open").count
    @pending_invitations = current_family.invitations.pending.count
    @organizers = current_family.memberships.where(role: "organizer").includes(:user).map { |m| m.user.label }
  end
end
