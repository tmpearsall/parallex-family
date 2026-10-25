class Membership < ApplicationRecord
  ROLES = %w[organizer member].freeze
  belongs_to :family
  belongs_to :user
  belongs_to :person, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :family_id }
  validate  :person_is_in_this_family
  validate  :family_keeps_an_organizer, on: :update

  def organizer? = role == "organizer"

  private

  def person_is_in_this_family
    errors.add(:person, "belongs to a different family") if person && person.family_id != family_id
  end

  def family_keeps_an_organizer
    return unless role_changed? && role == "member"
    errors.add(:base, "A family needs at least one organizer.") unless Membership.where(family_id: family_id, role: "organizer").where.not(id: id).exists?
  end
end
