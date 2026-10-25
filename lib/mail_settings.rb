# Where outgoing mail goes. Accepts the SMTP_* variables (the convention Parallex Advisory uses) and, as a
# convenience, a bare RESEND_API_KEY (Resend's SMTP is smtp.resend.com, user "resend", password = the key).
# Only names are ever shown to people, never values.
module MailSettings
  def self.resend_key? = ENV["RESEND_API_KEY"].present?

  def self.host     = ENV["SMTP_ADDRESS"].presence  || ("smtp.resend.com" if resend_key?)
  def self.username = ENV["SMTP_USERNAME"].presence || ("resend" if resend_key?)
  def self.password = ENV["SMTP_PASSWORD"].presence || ENV["RESEND_API_KEY"].presence
  def self.port     = ENV.fetch("SMTP_PORT", 587).to_i
  def self.tls?     = ENV["SMTP_TLS"] == "true"

  def self.configured? = host.present? && username.present? && password.present?

  # [[label, set?], ...] for the organizer's Email section when something is missing.
  def self.checklist
    [ [ "SMTP_ADDRESS (or RESEND_API_KEY)", host.present? ],
      [ "SMTP_USERNAME (or RESEND_API_KEY)", username.present? ],
      [ "SMTP_PASSWORD (or RESEND_API_KEY)", password.present? ],
      [ "MAIL_FROM", ENV["MAIL_FROM"].present? ] ]
  end
end
