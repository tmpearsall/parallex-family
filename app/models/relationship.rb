# One row per fact. "parent": from_person is a parent of to_person. "partner": from and to are partners
# (stored once; the reverse is derived). Siblings, grandparents, cousins and the rest are derived, never stored.
class Relationship < ApplicationRecord
  KINDS = %w[parent partner].freeze

  belongs_to :from_person, class_name: "Person"
  belongs_to :to_person,   class_name: "Person"

  validates :kind, inclusion: { in: KINDS }
  validates :notes, length: { maximum: 200 }
  validate :not_self
  validate :not_duplicate
  validate :parent_is_not_a_descendant, if: -> { kind == "parent" }

  scope :parents,  -> { where(kind: "parent") }
  scope :partners, -> { where(kind: "partner") }

  private

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
