class Membership < ApplicationRecord
  ROLES = %w[organizer member].freeze
  belongs_to :family
  belongs_to :user
  belongs_to :person, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :family_id }
  validate  :person_is_in_this_family
  validate  :family_keeps_an_organizer, on: :update
  validate  :owner_stays_an_organizer
  validate  :platform_operator_is_not_an_organizer

  def organizer? = role == "organizer"
  def owner? = owner

  # A secret address for subscribing to this member's calendar from a phone or computer calendar app. Calendar apps
  # cannot sign in, so the token is the credential; it is shown only to this member and can be replaced.
  def calendar_token!
    update_columns(calendar_token: SecureRandom.urlsafe_base64(24)) if calendar_token.blank?
    calendar_token
  end

  def unsubscribe_token!
    update_columns(unsubscribe_token: SecureRandom.urlsafe_base64(24)) if unsubscribe_token.blank?
    unsubscribe_token
  end

  def reset_calendar_token! = update_columns(calendar_token: SecureRandom.urlsafe_base64(24))

  private

  def person_is_in_this_family
    errors.add(:person, "belongs to a different family") if person && person.family_id != family_id
  end

  # On the commercial site the person who runs the platform is never an organizer or owner of a customer's group;
  # they can be a plain member if the owner invites them for support. (A dedicated site can choose otherwise.)
  def platform_operator_is_not_an_organizer
    return if Instance.dedicated?
    errors.add(:base, "The platform administrator cannot be an organizer or owner of a group.") if user&.platform_admin? && (role == "organizer" || owner)
  end

  def owner_stays_an_organizer
    errors.add(:base, "The owner has to be an organizer. Make someone else the owner first.") if owner && role != "organizer"
  end

  def family_keeps_an_organizer
    return unless role_changed? && role == "member"
    errors.add(:base, "A family needs at least one organizer.") unless Membership.where(family_id: family_id, role: "organizer").where.not(id: id).exists?
  end
end
