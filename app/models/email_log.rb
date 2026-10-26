# One outgoing email to one address, and what happened to it afterwards.
class EmailLog < ApplicationRecord
  STATUSES = %w[sending accepted delivered delayed bounced complained failed].freeze
  PROBLEM = %w[bounced complained failed].freeze
  belongs_to :family, optional: true

  validates :to_email, presence: true
  validates :status, inclusion: { in: STATUSES }
  before_validation { self.to_email = to_email.to_s.strip.downcase }

  # The latest known status for each address (a hash of email => status). Addresses never emailed are absent.
  def self.latest_statuses(emails)
    list = Array(emails).map { |e| e.to_s.strip.downcase }.reject(&:blank?).uniq
    return {} if list.empty?
    where(to_email: list).select("DISTINCT ON (to_email) to_email, status").order(:to_email, created_at: :desc).to_h { |r| [ r.to_email, r.status ] }
  end

  # Applies what the mail service reported to the most recent message to that address that was still open.
  def self.apply_event!(email:, status:, detail: nil)
    log = where(to_email: email.to_s.strip.downcase, status: %w[sending accepted delayed]).where("created_at > ?", 7.days.ago).order(created_at: :desc).first
    log ||= where(to_email: email.to_s.strip.downcase).where("created_at > ?", 7.days.ago).order(created_at: :desc).first
    return false unless log
    log.update!(status: status, detail: detail.to_s.first(200).presence, status_at: Time.current)
    true
  end

  def self.purge_old! = where("created_at < ?", 90.days.ago).delete_all
end
