# A message an organizer writes and sends to part of the family on the spot, outside the automatic daily digest.
# Only people who have not switched reminders off receive it. A daily cap per family keeps a mistake from becoming
# a flood, and every send is recorded.
class Announcement < ApplicationRecord
  AUDIENCES = %w[everyone rsvp_pending tasks_open].freeze
  DAILY_LIMIT = 60

  belongs_to :family
  belongs_to :user

  validates :audience, inclusion: { in: AUDIENCES }
  validates :body, presence: true, length: { maximum: 2000 }
  validates :subject, length: { maximum: 120 }
  before_validation { self.subject = subject.to_s.squish.presence }

  # Members who will get a message for this audience (never anyone who opted out).
  def self.recipients(family, audience, reunion = nil)
    base = family.memberships.where(email_reminders: true).includes(:user, :person)
    case audience
    when "tasks_open"
      ids = Task.joins(:reunion).where(reunions: { family_id: family.id }, done: false).where.not(claimed_by_id: nil).select(:claimed_by_id)
      base.where(user_id: ids).to_a
    when "rsvp_pending"
      return [] unless reunion
      answered = reunion.rsvps.pluck(:household_id)
      base.to_a.reject { |m| m.person&.household_id && answered.include?(m.person.household_id) }
    else
      base.to_a
    end
  end

  def self.sent_today(family) = where(family_id: family.id).where("created_at > ?", 24.hours.ago).sum(:recipient_count)
end
