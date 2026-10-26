class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Parallex Family <hello@parallexllc.com>") }
  layout false
  after_action :tag_for_the_log

  # Internal markers, read and removed by EmailLogInterceptor before the message leaves.
  def tag_for_the_log
    headers["X-Parallex-Family"] = @family.id.to_s if @family.respond_to?(:id)
    headers["X-Parallex-Kind"] = "#{mailer_name}.#{action_name}"
  end

  # On a dedicated family site the mail should read as coming from the family, not from the platform: keep the
  # sending address (it is what the mail service is verified for) but show the family's own name.
  def from_for(family)
    return self.class.from_address unless Instance.dedicated?
    addr = Mail::Address.new(self.class.from_address)
    addr.display_name = family.name
    addr.format
  end

  # True when a sending service is set up (production: SMTP_ADDRESS present). When false the app shows copyable
  # links and sends nothing.
  # What the Members page shows so an organizer can see where mail is going (never the password).
  def self.settings_summary = MailSettings.host.present? ? "through #{MailSettings.host}" : "(no sending service connected)"
  def self.from_address = ENV.fetch("MAIL_FROM", "Parallex Family <hello@parallexllc.com>")

  def self.configured? = ActionMailer::Base.perform_deliveries && (Rails.env.test? || Rails.env.development? || MailSettings.configured?)
end
