class EventsController < TenantController
  before_action :load, only: %i[show edit update destroy skip unskip]
  before_action :organizer_only!, only: %i[skip unskip]

  def index = redirect_to(calendar_path)
  def show; end
  def new
    meeting = organizer? && params[:meeting] == "1"
    @event = current_family.events.new(starts_on: params[:on].presence, reunion_id: params[:reunion_id].presence,
                                       organizers_only: meeting, repeat: (meeting ? params[:repeat].presence_in(Event::REPEATS) || "weekly" : "none"),
                                       title: (meeting ? params[:title].to_s.first(120).presence : nil))
  end

  def create
    @event = current_family.events.new(event_params.merge(created_by_id: current_user.id, updated_by_id: current_user.id))
    @event.save ? redirect_to(@event, notice: "Added to the calendar.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @event.update(event_params.merge(updated_by_id: current_user.id)) ? redirect_to(@event, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  # Cancel one date of a repeating event without ending the series, or bring it back.
  def skip
    day = parse_day(params[:date])
    return redirect_to(@event, alert: "That is not a date of this event.") unless day && @event.repeating? && @event.occurrence_days(day, day).include?(day)
    @event.update!(skipped_dates: Array(@event.skipped_dates) + [ day.to_s ])
    redirect_to @event, notice: "#{day.strftime('%b %-d')} is cancelled. The rest of the series goes on."
  end

  def unskip
    day = parse_day(params[:date])
    return redirect_to(@event, alert: "That is not a cancelled date.") unless day && Array(@event.skipped_dates).include?(day.to_s)
    @event.update!(skipped_dates: Array(@event.skipped_dates) - [ day.to_s ])
    redirect_to @event, notice: "#{day.strftime('%b %-d')} is back on."
  end

  def destroy
    return redirect_to(@event, alert: "Only an organizer can remove this now. You can remove an event you added for 48 hours.") unless @event.removable_by?(current_membership)
    @event.destroy
    redirect_to calendar_path, notice: "Removed."
  end

  private

  # Meetings only organizers can see are a 404 to everyone else.
  def load = @event = current_family.events.visible_to(current_membership).find(params[:id])

  # Only organizers can make an event organizers-only or repeating.
  def event_params
    p = params.require(:event).permit(:title, :starts_on, :ends_on, :time_note, :location, :notes, :reunion_id, :organizers_only, :repeat, :repeat_until)
    unless organizer?
      p.delete(:organizers_only)
      p.delete(:repeat)
      p.delete(:repeat_until)
    end
    p
  end

  def parse_day(text)
    Date.iso8601(text.to_s)
  rescue Date::Error
    nil
  end
end
