# People and access, for organizers: who is in the family, pending invitations, and inviting relatives. No email
# is sent yet: each invitation is a one-time link (7 days) the organizer copies and sends.
class MembersController < TenantController
  before_action :organizer_only!

  def index
    @memberships = current_family.memberships.includes(:user, :person).order(:created_at)
    @invitations = current_family.invitations.pending.includes(:person).order(created_at: :desc)
    @people = current_family.people.where.not(id: current_family.memberships.select(:person_id).where.not(person_id: nil)).by_name
    @prefill = current_family.people.find_by(id: params[:person_id])
  end

  # One or many emails at once (separated by spaces, commas or new lines). Each gets its own link.
  def create
    emails = params.dig(:invite, :emails).to_s.split(/[\s,;]+/).map(&:downcase).reject(&:blank?).uniq.first(40)
    person = current_family.people.find_by(id: params.dig(:invite, :person_id))
    role = Membership::ROLES.include?(params.dig(:invite, :role)) ? params.dig(:invite, :role) : "member"
    return redirect_to(members_path, alert: "Enter at least one email address.") if emails.empty?
    person = nil if emails.size > 1   # one person per link
    @results = emails.map do |email|
      if current_family.users.exists?(email: email)
        [ email, nil, "Already a member." ]
      else
        inv, raw = Invitation.issue!(family: current_family, email: email, role: role, person: person, invited_by: current_user)
        [ email, invitation_url(raw), nil ]
      end
    rescue ActiveRecord::RecordInvalid => e
      [ email, nil, e.record.errors.full_messages.to_sentence ]
    end
    render :links
  end

  def update
    m = current_family.memberships.find(params[:id])
    role = params[:role]
    return redirect_to(members_path, alert: "Unknown role.") unless Membership::ROLES.include?(role)
    m.role = role
    m.save ? redirect_to(members_path, notice: "Updated.") : redirect_to(members_path, alert: m.errors.full_messages.to_sentence)
  end

  def destroy
    m = current_family.memberships.find(params[:id])
    if m.organizer? && !current_family.memberships.where(role: "organizer").where.not(id: m.id).exists?
      return redirect_to(members_path, alert: "A family needs at least one organizer.")
    end
    m.destroy
    redirect_to members_path, notice: "Removed from the family."
  end

  def revoke
    current_family.invitations.find(params[:id]).destroy
    redirect_to members_path, notice: "Invitation withdrawn."
  end
end
