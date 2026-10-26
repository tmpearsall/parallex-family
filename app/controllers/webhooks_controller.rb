require "openssl"
require "base64"

# The mail service (Resend) tells the site what became of each message. The request is signed (Svix scheme: an id, a
# timestamp and an HMAC of "id.timestamp.body" with the endpoint's signing secret), so only the real service can
# change a message's status. With no secret set the endpoint refuses everything.
class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection
  TOLERANCE = 5.minutes
  STATUS_FOR = { "email.delivered" => "delivered", "email.bounced" => "bounced", "email.complained" => "complained",
                 "email.delivery_delayed" => "delayed", "email.failed" => "failed" }.freeze

  def resend
    secret = ENV["RESEND_WEBHOOK_SECRET"].to_s
    return head(:service_unavailable) if secret.blank?
    body = request.raw_post
    return head(:unauthorized) unless self.class.valid_signature?(secret, request.headers["svix-id"], request.headers["svix-timestamp"], request.headers["svix-signature"], body)
    event = JSON.parse(body)
    status = STATUS_FOR[event["type"]]
    if status
      data = event["data"] || {}
      detail = data.dig("bounce", "message") || data.dig("bounce", "type") || data["reason"]
      Array(data["to"]).each { |addr| EmailLog.apply_event!(email: addr, status: status, detail: detail) }
    end
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  def self.valid_signature?(secret, id, timestamp, signature_header, body)
    return false if id.blank? || timestamp.blank? || signature_header.blank?
    return false if (Time.current.to_i - timestamp.to_i).abs > TOLERANCE
    key = Base64.decode64(secret.sub(/\Awhsec_/, ""))
    expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, "#{id}.#{timestamp}.#{body}"))
    signature_header.split(" ").any? do |part|
      version, sig = part.split(",", 2)
      version == "v1" && sig.present? && ActiveSupport::SecurityUtils.secure_compare(sig, expected)
    end
  end
end
