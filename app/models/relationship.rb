# One row per fact. "parent": from_person is a parent of to_person. "partner": from and to are partners
# (stored once; the reverse is derived). Siblings, grandparents, cousins and the rest are derived, never stored.
class Relationship < ApplicationRecord
  KINDS = %w[parent partner].freeze

  belongs_to :family
  belongs_to :from_person, class_name: "Person"
  belongs_to :to_person,   class_name: "Person"

  before_validation { self.family_id ||= from_person&.family_id }
  validates :kind, inclusion: { in: KINDS }
  validate :both_people_are_in_the_family
  validates :notes, length: { maximum: 200 }
  validate  :started_on_only_for_partners
  validate :not_self
  validate :not_duplicate
  validate :parent_is_not_a_descendant, if: -> { kind == "parent" }

  scope :parents,  -> { where(kind: "parent") }
  scope :partners, -> { where(kind: "partner") }

  private

  def started_on_only_for_partners = (errors.add(:started_on, "only applies to partners") if started_on && kind != "partner")

  def both_people_are_in_the_family
    return if from_person.blank? || to_person.blank?
    errors.add(:base, "Both people must be in the same family.") unless from_person.family_id == family_id && to_person.family_id == family_id
  end

  def not_self
    errors.add(:base, "A person cannot be related to themselves.") if from_person_id.present? && from_person_id == to_person_id
  end

  def not_duplicate
    return if from_person_id.blank? || to_person_id.blank?
    dup = Relationship.where(kind: kind).where.not(id: id)
    dup = kind == "partner" ? dup.where(from_person_id: [ from_person_id, to_person_id ], to_person_id: [ from_person_id, to_person_id ]) : dup.where(from_person_id: from_person_id, to_person_id: to_person_id)
    errors.add(:base, "That relationship is already recorded.") if dup.exists?
  end

  # A parent cannot also be the child, grandchild and so on of the same person.
  def parent_is_not_a_descendant
    return if from_person_id.blank? || to_person_id.blank? || from_person_id == to_person_id
    seen = Set.new
    frontier = [ from_person_id ]
    until frontier.empty?
      parents = Relationship.parents.where(to_person_id: frontier).pluck(:from_person_id) - seen.to_a
      if parents.include?(to_person_id)
        errors.add(:base, "That would make #{to_person.display_name} their own ancestor.")
        return
      end
      seen.merge(parents)
      frontier = parents
    end
  end
end
