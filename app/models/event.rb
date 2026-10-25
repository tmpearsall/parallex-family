# A gathering or deadline on the family calendar. Whole days only, with a free-text time note.
class Event < ApplicationRecord
  EDIT_WINDOW = 48.hours
  REPEATS = %w[none weekly biweekly monthly].freeze
  MAX_YEARS = 2   # a repeating event with no end date stops generating after this long

  belongs_to :family
  belongs_to :reunion, optional: true
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  belongs_to :editor,  class_name: "User", foreign_key: :updated_by_id, optional: true

  validates :title, presence: true, length: { maximum: 120 }
  validates :starts_on, presence: true
  validates :time_note, :location, length: { maximum: 120 }
  validates :notes, length: { maximum: 2000 }
  validates :repeat, inclusion: { in: REPEATS }
  validate  :ends_after_start
  validate  :repeat_until_after_start
  validate  :reunion_is_in_this_family
  before_validation { %i[title time_note location].each { |a| self[a] = self[a].to_s.squish.presence } }

  # A standing meeting that stops by itself at the reunion when no end date is given.
  before_save do
    self.repeat_until ||= reunion.starts_on if repeat != "none" && reunion&.starts_on && reunion.starts_on >= starts_on
    self.repeat_until = nil if repeat == "none"
    self.skipped_dates = Array(skipped_dates).map(&:to_s).uniq.sort
  end

  scope :overlapping, ->(from, to) { where("starts_on <= ? and (repeat <> 'none' or coalesce(ends_on, starts_on) >= ?)", to, from) }
  scope :visible_to, ->(membership) { membership.organizer? ? all : where(organizers_only: false) }

  def last_day = ends_on || starts_on
  def repeating? = repeat != "none"
  def meeting? = organizers_only
  def visible_to?(membership) = !organizers_only || membership.organizer?
  def duration_days = ((ends_on || starts_on) - starts_on).to_i

  # First days of each occurrence that touches from..to (skipped dates left out). A one-off event is one occurrence.
  def occurrence_days(from, to)
    return ((starts_on <= to && last_day >= from) ? [ starts_on ] : []) unless repeating?
    limit = [ repeat_until || (starts_on >> (12 * MAX_YEARS)), to ].min
    skipped = Array(skipped_dates)
    out = []
    n = 0
    loop do
      day = occurrence_on(n)
      break if day > limit
      out << day if day + duration_days >= from && !skipped.include?(day.to_s)
      n += 1
      break if n > 800
    end
    out
  end

  def occurs_on?(day) = occurrence_days(day, day).any?

  def repeat_label = { "weekly" => "every week", "biweekly" => "every two weeks", "monthly" => "every month" }[repeat]

  def occurrence_on(n)
    case repeat
    when "weekly" then starts_on + (7 * n)
    when "biweekly" then starts_on + (14 * n)
    when "monthly" then starts_on >> n
    else starts_on
    end
  end

  def removable_by?(membership) = membership.organizer? || (created_by_id == membership.user_id && created_at > EDIT_WINDOW.ago)

  private

  def ends_after_start = (errors.add(:ends_on, "is before the start") if starts_on && ends_on && ends_on < starts_on)
  def repeat_until_after_start = (errors.add(:repeat_until, "is before the start") if repeat_until && starts_on && repeat_until < starts_on)
  def reunion_is_in_this_family = (errors.add(:reunion, "belongs to a different family") if reunion && reunion.family_id != family_id)
end
