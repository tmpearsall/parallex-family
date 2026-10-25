require "test_helper"

class MailSettingsTest < ActiveSupport::TestCase
  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  NONE = { "SMTP_ADDRESS" => nil, "SMTP_USERNAME" => nil, "SMTP_PASSWORD" => nil, "RESEND_API_KEY" => nil, "SMTP_TLS" => nil, "SMTP_PORT" => nil }.freeze

  test "nothing set means not configured, and the checklist says what is missing" do
    with_env(NONE) do
      assert_not MailSettings.configured?
      assert_equal [ false, false, false ], MailSettings.checklist.first(3).map(&:last)
    end
  end

  test "SMTP_* variables configure it" do
    with_env(NONE.merge("SMTP_ADDRESS" => "smtp.resend.com", "SMTP_USERNAME" => "resend", "SMTP_PASSWORD" => "key")) do
      assert MailSettings.configured?
      assert_equal 587, MailSettings.port
      assert_not MailSettings.tls?
    end
  end

  test "a bare RESEND_API_KEY is enough for Resend" do
    with_env(NONE.merge("RESEND_API_KEY" => "re_123")) do
      assert MailSettings.configured?
      assert_equal [ "smtp.resend.com", "resend", "re_123" ], [ MailSettings.host, MailSettings.username, MailSettings.password ]
    end
  end

  test "a host without credentials is not configured" do
    with_env(NONE.merge("SMTP_ADDRESS" => "smtp.example.test")) do
      assert_not MailSettings.configured?
    end
  end

  test "port 465 with SMTP_TLS uses implicit TLS" do
    with_env(NONE.merge("SMTP_PORT" => "465", "SMTP_TLS" => "true")) do
      assert_equal 465, MailSettings.port
      assert MailSettings.tls?
    end
  end
end
