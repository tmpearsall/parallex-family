class RsvpsController < TenantController
  def create
    reunion = current_family.reunions.find(params[:reunion_id])
    household = current_family.households.find(params.dig(:rsvp, :household_id))
    rsvp = reunion.rsvps.find_or_initialize_by(household: household)
    rsvp.assign_attributes(params.require(:rsvp).permit(:status, :adults, :children, :dietary, :lodging_needed, :arrival_on, :departure_on, :notes).merge(updated_by_id: current_user.id))
    rsvp.save ? redirect_to(reunion, notice: "RSVP saved for #{household.name}.") : redirect_to(reunion, alert: rsvp.errors.full_messages.to_sentence)
  end
end
