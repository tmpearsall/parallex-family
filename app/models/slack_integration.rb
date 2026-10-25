# One organization's Slack channel. Anyone holding the webhook address can post to the channel, so it is stored
# encrypted (keyed from the app's secret) and never shown again after it is saved. Only Slack's own address is accepted.
class SlackIntegration < ApplicationRecord
  WEBHOOK_PATTERN = %r{\Ahttps://hooks\.slack\.com/services/[A-Za-z0-9/_-]{20,200}\z}
  KINDS = { "meetings" => :notify_meetings, "forum" => :notify_forum, "surveys" => :notify_surveys,
            "deadlines" => :notify_deadlines, "messages" => :notify_messages }.freeze

  belongs_to :family
  validates :webhook_ciphertext, presence: true
  validates :family_id, uniqueness: true

  def self.encryptor = ActiveSupport::MessageEncryptor.new(Rails.application.key_generator.generate_key("slack webhook", 32), cipher: "aes-256-gcm")
  def self.valid_webhook?(url) = url.to_s.strip.match?(WEBHOOK_PATTERN)

  def webhook_url = self.class.encryptor.decrypt_and_verify(webhook_ciphertext)
  def webhook_url=(url)
    self.webhook_ciphertext = self.class.encryptor.encrypt_and_sign(url.to_s.strip)
  end

  def wants?(kind) = KINDS.key?(kind.to_s) && public_send(KINDS[kind.to_s])
end
