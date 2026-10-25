require "digest"

# One person's personal link to one survey. The raw token exists only in the email; here lives its digest.
class SurveyRecipient < ApplicationRecord
  belongs_to :survey
  belongs_to :person, optional: true
  belongs_to :membership, optional: true
  has_one :response, class_name: "SurveyResponse", foreign_key: :survey_recipient_id, dependent: :destroy

  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  before_validation { self.email = email.to_s.strip.downcase }

  def self.digest(raw) = Digest::SHA256.hexdigest(raw.to_s)
  def self.find_by_token(raw) = raw.to_s.length.between?(20, 80) ? find_by(token_digest: digest(raw)) : nil

  # A fresh link (the old one stops working). Returns the raw token.
  def issue_token!
    raw = SecureRandom.urlsafe_base64(24)
    update!(token_digest: self.class.digest(raw))
    raw
  end

  def responded? = response.present?
end
