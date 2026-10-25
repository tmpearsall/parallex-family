# Who is in this family, for every member: display names and where they sit in the tree. Emails are shown
# only to organizers, who also manage access on the Members page.
class DirectoryController < TenantController
  # Each member decides whether to get reminder emails for this family.
  def reminders
    current_membership.update!(email_reminders: params[:on] == "1")
    redirect_to directory_path, notice: (current_membership.email_reminders ? "Reminder emails are on." : "Reminder emails are off.")
  end

  def show
    @memberships = current_family.memberships.includes(:user, :person).sort_by { |m| m.user.label.downcase }
    @without_account = current_family.people.where.not(id: current_family.memberships.select(:person_id).where.not(person_id: nil)).by_name
  end
end
