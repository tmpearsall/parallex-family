# Runs the reminder digests once a day inside the web process, at 13:00 UTC (9 am Eastern), so no separate
# scheduler service is needed. It only starts when the server boots in production with email configured.
# Running twice, or missing a day, is harmless: ReminderRunner never repeats a reminder, and each item is due on a
# window of dates.
Rails.application.config.after_initialize do
  next unless Rails.env.production? && MailSettings.configured? && ENV["REMINDER_SCHEDULER"] != "off"
  next unless defined?(Rails::Server) || ENV["PUMA_CONTROL_URL"] || $PROGRAM_NAME.include?("puma")

  Thread.new do
    Thread.current.name = "reminder-scheduler"
    loop do
      now = Time.now.utc
      target = Time.utc(now.year, now.month, now.day, 13, 0, 0)
      target += 1.day if target <= now
      sleep(target - now)
      begin
        ActiveRecord::Base.connection_pool.with_connection do
          Rails.logger.info("reminders: #{ReminderRunner.new.run.inspect}")
        end
      rescue StandardError => e
        Rails.logger.error("reminders: run failed: #{e.class}: #{e.message}")
      end
    end
  end
end
