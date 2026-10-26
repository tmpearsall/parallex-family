# Records every outgoing message before it is sent (so the mail service's later report can be matched to it), and takes
# the internal headers back off so they never reach the recipient. After delivery the observer marks it accepted.
class EmailLogInterceptor
  def self.delivering_email(message)
    family_id = message.header["X-Parallex-Family"]&.value.to_s.presence
    kind = message.header["X-Parallex-Kind"]&.value.to_s.presence || "other"
    message.header["X-Parallex-Family"] = nil
    message.header["X-Parallex-Kind"] = nil
    Array(message.to).each do |to|
      EmailLog.create!(family_id: family_id, kind: kind, to_email: to, subject: message.subject.to_s.first(200), status: "sending")
    end
  rescue StandardError => e
    Rails.logger.error("email log (before send) failed: #{e.class}")
  end
end

class EmailLogObserver
  def self.delivered_email(message)
    Array(message.to).each do |to|
      log = EmailLog.where(to_email: to.to_s.downcase, status: "sending").order(created_at: :desc).first
      log&.update!(status: "accepted", status_at: Time.current)
    end
  rescue StandardError => e
    Rails.logger.error("email log (after send) failed: #{e.class}")
  end
end
