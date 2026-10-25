# Connect an organization's Slack channel. Commercial site only. Organizers can see the status; only the owner can
# connect, change or disconnect it (the address is a credential).
class SlackIntegrationsController < TenantController
  before_action :commercial_only!
  before_action :organizer_only!
  before_action :owner_only!, only: %i[update destroy test]

  def show
    @integration = current_family.slack_integration
  end

  def update
    integ = current_family.slack_integration || current_family.build_slack_integration
    url = params.dig(:slack, :webhook_url).to_s.strip
    if url.present?
      return redirect_to(slack_path, alert: "That is not a Slack webhook address. It starts with https://hooks.slack.com/services/") unless SlackIntegration.valid_webhook?(url)
      integ.webhook_url = url
    elsif integ.new_record?
      return redirect_to(slack_path, alert: "Paste the webhook address from Slack first.")
    end
    SlackIntegration::KINDS.each_value { |col| integ[col] = params.dig(:slack, col) == "1" }
    integ.save!
    redirect_to slack_path, notice: "Saved. Use \"Send a test message\" to check it."
  end

  def test
    integ = current_family.slack_integration
    return redirect_to(slack_path, alert: "Connect Slack first.") unless integ
    SlackNotifier.test(integ) ? redirect_to(slack_path, notice: "Sent. Look in the Slack channel.") : redirect_to(slack_path, alert: "Slack did not accept it. Check the address, or make a new webhook in Slack.")
  end

  def destroy
    current_family.slack_integration&.destroy
    redirect_to slack_path, notice: "Slack is disconnected and the address is deleted."
  end

  private

  def commercial_only! = (head :not_found if Instance.dedicated?)
  def owner_only! = (redirect_to(slack_path, alert: "Only the owner can change this.") unless owner?)
end
