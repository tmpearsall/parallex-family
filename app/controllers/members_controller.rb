# People and access, for organizers: who is in the family, pending invitations, and inviting relatives. No email
# is sent yet: each invitation is a one-time link (7 days) the organizer copies and sends.
class MembersController < TenantController
  before_action :organizer_only!

  def index
    @memberships = current_family.memberships.includes(:user, :person).order(:created_at)
    @invitations = current_family.invitations.pending.includes(:person).order(created_at: :desc)
    @people = current_family.people.where.not(id: current_family.memberships.select(:person_id).where.not(person_id: nil)).by_name
    @prefill = current_family.people.find_by(id: params[:person_id])
    @email_status = EmailLog.latest_statuses(@memberships.map { |m| m.user.email })
    @events = current_family.membership_events.includes(:actor_user).order(created_at: :desc).limit(15)
  end

  DAILY_INVITATION_LIMIT = 60

  # One or many emails at once (separated by spaces, commas or new lines). Each gets its own one-time link, and
  # when a sending service is configured and "Email it" is ticked, the link is emailed too. The link is always
  # shown here as well, as a fallback.
  def create
    emails = params.dig(:invite, :emails).to_s.split(/[\s,;]+/).map(&:downcase).reject(&:blank?).uniq.first(40)
    person = current_family.people.find_by(id: params.dig(:invite, :person_id))
    role = Membership::ROLES.include?(params.dig(:invite, :role)) ? params.dig(:invite, :role) : "member"
    return redirect_to(members_path, alert: "Only the owner can invite an organizer. You can invite members.") if role == "organizer" && !owner?
    return redirect_to(members_path, alert: "Enter at least one email address.") if emails.empty?
    if current_family.invitations.where("created_at > ?", 24.hours.ago).count + emails.size > DAILY_INVITATION_LIMIT
      return redirect_to(members_path, alert: "That is more than #{DAILY_INVITATION_LIMIT} invitations in a day. Try again tomorrow.")
    end
    person = nil if emails.size > 1   # one person per link
    if person.nil? && emails.size == 1 && params.dig(:invite, :new_first_name).present?
      person, problem = add_person_for_invite(emails.first)
      return redirect_to(members_path, alert: problem) if problem
    end
    send_mail = params.dig(:invite, :send_email) == "1" && ApplicationMailer.configured?
    @results = emails.map { |email| invite_one(email, role, person, send_mail) }
    @results.each { |email, url, problem, _| MembershipEvent.record!(family: current_family, actor: current_user, kind: "invited_organizer", target: email) if role == "organizer" && url && problem.nil? }
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

  # An organizer sends themselves a test message, to see that mail really leaves and where it lands.
  def test_email
    return redirect_to(members_path, alert: "Email sending is not set up yet.") unless ApplicationMailer.configured?
    TestMailer.with(user: current_user, family: current_family).hello.deliver_now
    redirect_to members_path, notice: "A test email was sent to #{current_user.email}. Check the inbox and the spam folder."
  rescue StandardError => e
    Rails.logger.error("test email failed: #{e.class}: #{e.message}")
    redirect_to members_path, alert: "The test email failed: #{e.message.to_s.truncate(200)}"
  end

  # Only the owner changes who organizes. The owner's own role never changes here (transfer ownership first).
  def update
    return redirect_to(members_path, alert: "Only the owner can change who organizes.") unless owner?
    m = current_family.memberships.find(params[:id])
    role = params[:role]
    return redirect_to(members_path, alert: "Unknown role.") unless Membership::ROLES.include?(role)
    return redirect_to(members_path, alert: "The owner stays an organizer. Make someone else the owner first.") if m.owner?
    m.role = role
    if m.save
      MembershipEvent.record!(family: current_family, actor: current_user, kind: role == "organizer" ? "made_organizer" : "made_member", target: m.user.label) if m.saved_change_to_role?
      redirect_to members_path, notice: "Updated."
    else
      redirect_to members_path, alert: m.errors.full_messages.to_sentence
    end
  end

  # Any organizer can remove a member. Removing an organizer is the owner's call; the owner cannot be removed.
  def destroy
    m = current_family.memberships.find(params[:id])
    return redirect_to(members_path, alert: "The owner cannot be removed. Make someone else the owner first.") if m.owner?
    if m.organizer? && !owner? && m.id != current_membership.id
      return redirect_to(members_path, alert: "Only the owner can remove an organizer.")
    end
    if m.organizer? && !current_family.memberships.where(role: "organizer").where.not(id: m.id).exists?
      return redirect_to(members_path, alert: "A #{terms.group} needs at least one organizer.")
    end
    was_organizer = m.organizer?
    label = m.user.label
    m.destroy
    MembershipEvent.record!(family: current_family, actor: current_user, kind: "removed_organizer", target: label) if was_organizer
    redirect_to members_path, notice: "Removed from the #{terms.group}."
  end

  # The owner hands ownership to another organizer; the previous owner stays an organizer.
  def make_owner
    return redirect_to(members_path, alert: "Only the owner can hand over ownership.") unless owner?
    target = current_family.memberships.find(params[:id])
    return redirect_to(members_path, alert: "Ownership goes to an organizer. Make them an organizer first.") unless target.organizer?
    return redirect_to(members_path, alert: "They are already the owner.") if target.owner?
    Membership.transaction do
      current_membership.update!(owner: false)
      target.update!(owner: true)
    end
    MembershipEvent.record!(family: current_family, actor: current_user, kind: "ownership_transferred", target: target.user.label)
    redirect_to members_path, notice: "#{target.user.label} is now the owner."
  end

  def revoke
    current_family.invitations.find(params[:id]).destroy
    redirect_to members_path, notice: "Invitation withdrawn."
  end

  private

  RELATIONS = %w[child parent partner].freeze

  # "Not in the list? Add them": makes the person (so the link has someone to point at) and, when asked and the
  # family tree is on, records how they are related to someone already in the tree. Returns [person, problem].
  def add_person_for_invite(email)
    first = params.dig(:invite, :new_first_name).to_s
    last = params.dig(:invite, :new_last_name).to_s
    relation = params.dig(:invite, :relation).to_s
    related = current_family.people.find_by(id: params.dig(:invite, :related_to_id))
    person = nil
    Person.transaction do
      person = current_family.people.create!(first_name: first, last_name: last, email: email, created_by_id: current_user.id, updated_by_id: current_user.id)
      if terms.tree? && RELATIONS.include?(relation) && related
        from, to = case relation
        when "child"   then [ related, person ]
        when "parent"  then [ person, related ]
        else [ related, person ]
        end
        current_family.relationships.create!(from_person: from, to_person: to, kind: relation == "partner" ? "partner" : "parent")
      end
    end
    [ person, nil ]
  rescue ActiveRecord::RecordInvalid => e
    [ nil, e.record.errors.full_messages.to_sentence ]
  end

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
