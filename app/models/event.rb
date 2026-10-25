# A gathering or deadline on the family calendar. Whole days only, with a free-text time note.
class Event < ApplicationRecord
  EDIT_WINDOW = 48.hours

  belongs_to :family
  belongs_to :reunion, optional: true
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  belongs_to :editor,  class_name: "User", foreign_key: :updated_by_id, optional: true

  validates :title, presence: true, length: { maximum: 120 }
  validates :starts_on, presence: true
  validates :time_note, :location, length: { maximum: 120 }
  validates :notes, length: { maximum: 2000 }
  validate  :ends_after_start
  validate  :reunion_is_in_this_family
  before_validation { %i[title time_note location].each { |a| self[a] = self[a].to_s.squish.presence } }

  scope :overlapping, ->(from, to) { where("starts_on <= ? and coalesce(ends_on, starts_on) >= ?", to, from) }

  def last_day = ends_on || starts_on
  def removable_by?(membership) = membership.organizer? || (created_by_id == membership.user_id && created_at > EDIT_WINDOW.ago)

  private

  def ends_after_start = (errors.add(:ends_on, "is before the start") if starts_on && ends_on && ends_on < starts_on)
  def reunion_is_in_this_family = (errors.add(:reunion, "belongs to a different family") if reunion && reunion.family_id != family_id)
end
