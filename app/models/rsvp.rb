class Rsvp < ApplicationRecord
  STATUSES = %w[attending maybe not_attending].freeze
  LABELS = { "attending" => "Coming", "maybe" => "Maybe", "not_attending" => "Can't come" }.freeze

  belongs_to :reunion
  belongs_to :household
  validates :status, inclusion: { in: STATUSES }
  validates :adults, :children, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 50 }
  validates :household_id, uniqueness: { scope: :reunion_id }
  validates :dietary, :notes, length: { maximum: 1000 }
  validate :someone_is_coming, if: -> { status == "attending" }
  validate { errors.add(:departure_on, "is before arrival") if arrival_on && departure_on && departure_on < arrival_on }

  def label = LABELS[status]
  def people = adults + children

  private

  def someone_is_coming = (errors.add(:base, "Say how many are coming.") if adults + children < 1)
end
