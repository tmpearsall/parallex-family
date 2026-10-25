class SettingsController < TenantController
  before_action :organizer_only!

  def update
    if current_family.update(name: params[:name])
      redirect_to members_path, notice: "Renamed."
    else
      redirect_to members_path, alert: current_family.errors.full_messages.to_sentence
    end
  end
end
