# Who is in this family, for every member: display names and where they sit in the tree. Emails are shown
# only to organizers, who also manage access on the Members page.
class DirectoryController < TenantController
  def show
    @memberships = current_family.memberships.includes(:user, :person).sort_by { |m| m.user.label.downcase }
    @without_account = current_family.people.where.not(id: current_family.memberships.select(:person_id).where.not(person_id: nil)).by_name
  end
end
