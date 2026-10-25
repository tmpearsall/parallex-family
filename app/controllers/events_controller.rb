class EventsController < TenantController
  before_action :load, only: %i[show edit update destroy]

  def index = redirect_to(calendar_path)
  def show; end
  def new = @event = current_family.events.new(starts_on: params[:on].presence, reunion_id: params[:reunion_id].presence)

  def create
    @event = current_family.events.new(event_params.merge(created_by_id: current_user.id, updated_by_id: current_user.id))
    @event.save ? redirect_to(@event, notice: "Added to the calendar.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @event.update(event_params.merge(updated_by_id: current_user.id)) ? redirect_to(@event, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    return redirect_to(@event, alert: "Only an organizer can remove this now. You can remove an event you added for 48 hours.") unless @event.removable_by?(current_membership)
    @event.destroy
    redirect_to calendar_path, notice: "Removed."
  end

  private

  def load = @event = current_family.events.find(params[:id])
  def event_params = params.require(:event).permit(:title, :starts_on, :ends_on, :time_note, :location, :notes, :reunion_id)
end
