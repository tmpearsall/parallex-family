# One place for the people who organize: everything an organizer can do beyond what a member can, gathered on a
# single page. Organizers only.
class AdminController < TenantController
  before_action :organizer_only!

  def show
    @people_count = current_family.people.count
    emails = current_family.people.where.not(email: nil).pluck(:email)
    st = EmailLog.latest_statuses(emails)
    @not_reached = st.values.count { |v| EmailLog::PROBLEM.include?(v) } + current_family.people.where(email: nil, death_date: nil).count
    @open_surveys = current_family.surveys.where(status: "open").count
    @pending_invitations = current_family.invitations.pending.count
    @organizers = current_family.memberships.where(role: "organizer").includes(:user).map { |m| m.user.label }
  end
end
