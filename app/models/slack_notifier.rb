require "net/http"
require "json"

# Posts short messages to an organization's Slack channel. It never raises (a Slack problem must not break the page
# or the daily run), never follows redirects, and only ever carries titles, times, counts and display names: no
# phone numbers, addresses, emails or forum text. Commercial site only.
module SlackNotifier
  class << self
    # Tests replace this with a recorder; production uses the real HTTPS post.
    attr_writer :transport

    def transport = @transport || method(:post_to_slack)

    def enabled_for?(family, kind)
      !Instance.dedicated? && family.slack_integration&.wants?(kind)
    end

    # Returns true when Slack accepted the message.
    def post(family, kind, text)
      integ = family.slack_integration
      return false unless integ && enabled_for?(family, kind)
      ok = transport.call(integ.webhook_url, { text: text }.to_json)
      integ.update_columns(last_status: ok ? "ok" : "failed", last_posted_at: Time.current)
      ok
    rescue StandardError => e
      Rails.logger.error("slack post failed for family #{family.id}: #{e.class}")
      integ&.update_columns(last_status: "failed")
      false
    end

    # Used by the "send a test message" button: always sends, regardless of the per-kind switches.
    def test(integration)
      ok = transport.call(integration.webhook_url, { text: "Test from #{integration.family.name}: Slack is connected." }.to_json)
      integration.update_columns(last_status: ok ? "ok" : "failed", last_posted_at: Time.current)
      ok
    rescue StandardError => e
      Rails.logger.error("slack test failed for family #{integration.family_id}: #{e.class}")
      integration.update_columns(last_status: "failed")
      false
    end

    # Slack treats & < > as markup.
    def esc(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")

    def link(path)
      o = Rails.application.config.action_mailer.default_url_options.to_h
      "#{o[:protocol] || 'https'}://#{o[:host]}#{path}"
    end

    private

    def post_to_slack(url, json)
      uri = URI(url)
      return false unless SlackIntegration.valid_webhook?(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 2
      http.read_timeout = 3
      res = http.post(uri.request_uri, json, "Content-Type" => "application/json")
      res.is_a?(Net::HTTPSuccess)
    end
  end
end
