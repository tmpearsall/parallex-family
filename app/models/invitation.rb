# A one-time link an organizer hands to someone to join a family. No email is sent (yet): the organizer copies
# the link. Only the SHA-256 of the token is stored, so a leaked database cannot be used to join.
class Invitation < ApplicationRecord
  VALID_FOR = 7.days
  belongs_to :family
  belongs_to :person, optional: true
  belongs_to :invited_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :role, inclusion: { in: Membership::ROLES }
  validate  :person_is_in_this_family
  validate  :not_the_platform_administrator_as_organizer
  before_validation { self.email = email.to_s.strip.downcase }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }

  def self.digest(raw) = Digest::SHA256.hexdigest(raw.to_s)
  def self.find_by_token(raw) = pending.find_by(token_digest: digest(raw))

  # Creates the invitation and returns [invitation, raw_token]. The raw token is never stored.
  def self.issue!(family:, email:, role: "member", person: nil, invited_by: nil)
    raw = SecureRandom.urlsafe_base64(32)
    inv = create!(family: family, email: email, role: role, person: person, invited_by: invited_by,
                  token_digest: digest(raw), expires_at: VALID_FOR.from_now)
    [ inv, raw ]
  end

  # Mail is only attempted when a sending service is configured.
  def mark_emailed! = update_columns(emailed_at: Time.current, email_error: nil)
  def mark_email_failed!(message) = update_columns(email_error: message.to_s.truncate(200))

  def pending? = accepted_at.nil? && expires_at > Time.current

  # Join the family as this user. Idempotent for someone already in it.
  def accept!(user)
    transaction do
      m = family.memberships.find_or_initialize_by(user: user)
      if m.new_record?
        m.role = role
        m.person = person
        m.owner = true if role == "organizer" && !family.memberships.exists?(owner: true)   # the first organizer of a new workspace
        m.save!
      end
      update!(accepted_at: Time.current)
      m
    end
  end

  private

  def not_the_platform_administrator_as_organizer
    return if Instance.dedicated? || role != "organizer" || email.blank?
    errors.add(:base, "The platform administrator cannot be invited as an organizer. Invite them as a member if you want them to help.") if User.exists?(email: email, platform_admin: true)
  end

  def person_is_in_this_family
    errors.add(:person, "belongs to a different family") if person && person.family_id != family_id
  end
end
