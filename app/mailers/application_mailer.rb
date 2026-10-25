class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Parallex Family <hello@parallexllc.com>") }
  layout false

  # True when a sending service is set up (production: SMTP_ADDRESS present). When false the app shows copyable
  # links and sends nothing.
  def self.configured? = ActionMailer::Base.perform_deliveries && (Rails.env.test? || ENV["SMTP_ADDRESS"].present? || Rails.env.development?)
end
