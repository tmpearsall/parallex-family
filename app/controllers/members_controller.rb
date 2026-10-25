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

  DAILY_INVITATION_LIMIT = 60

  # One or many emails at once (separated by spaces, commas or new lines). Each gets its own one-time link, and
  # when a sending service is configured and "Email it" is ticked, the link is emailed too. The link is always
  # shown here as well, as a fallback.
  def create
    emails = params.dig(:invite, :emails).to_s.split(/[\s,;]+/).map(&:downcase).reject(&:blank?).uniq.first(40)
    person = current_family.people.find_by(id: params.dig(:invite, :person_id))
    role = Membership::ROLES.include?(params.dig(:invite, :role)) ? params.dig(:invite, :role) : "member"
    return redirect_to(members_path, alert: "Enter at least one email address.") if emails.empty?
    if current_family.invitations.where("created_at > ?", 24.hours.ago).count + emails.size > DAILY_INVITATION_LIMIT
      return redirect_to(members_path, alert: "That is more than #{DAILY_INVITATION_LIMIT} invitations in a day. Try again tomorrow.")
    end
    person = nil if emails.size > 1   # one person per link
    send_mail = params.dig(:invite, :send_email) == "1" && ApplicationMailer.configured?
    @results = emails.map { |email| invite_one(email, role, person, send_mail) }
    @mail_on = send_mail
    render :links
  end

  # A fresh link for someone who has not accepted (the old one cannot be recovered): withdraws the old invitation
  # and issues a new one, emailing it when email is set up.
  def resend
    old = current_family.invitations.pending.find(params[:id])
    result = nil
    Invitation.transaction do
      old.destroy
      result = invite_one(old.email, old.role, old.person, ApplicationMailer.configured?)
    end
    @results = [ result ]
    @mail_on = ApplicationMailer.configured?
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

  private

  # Returns [email, url_or_nil, problem_or_nil, status] where status is :emailed, :email_failed or :link_only.
  def invite_one(email, role, person, send_mail)
    return [ email, nil, "Already a member.", nil ] if current_family.users.exists?(email: email)
    inv, raw = Invitation.issue!(family: current_family, email: email, role: role, person: person, invited_by: current_user)
    url = invitation_url(raw, family: nil)
    status = :link_only
    if send_mail
      begin
        InvitationMailer.with(invitation: inv, url: url, inviter: current_user).invite.deliver_now
        inv.mark_emailed!
        status = :emailed
      rescue StandardError => e
        inv.mark_email_failed!("#{e.class}: #{e.message}")
        Rails.logger.error("invitation email failed for #{email}: #{e.class}: #{e.message}")
        status = :email_failed
      end
    end
    [ email, url, nil, status ]
  rescue ActiveRecord::RecordInvalid => e
    [ email, nil, e.record.errors.full_messages.to_sentence, nil ]
  end
end
