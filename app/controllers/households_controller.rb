class HouseholdsController < TenantController
  before_action :load, only: %i[show edit update add_people]

  def index = @households = current_family.households.includes(:people).order(:name)
  def show = @members = @household.people.by_name
  def new = @household = current_family.households.new

  def create
    @household = current_family.households.new(params.require(:household).permit(:name, :city, :region, :notes).merge(created_by_id: current_user.id, updated_by_id: current_user.id))
    @household.save ? redirect_to(@household, notice: "Household added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @household.update(params.require(:household).permit(:name, :city, :region, :notes).merge(updated_by_id: current_user.id)) ? redirect_to(@household, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  # Several people at once: one name per line. A single word takes the default last name.
  def add_people
    lines = params[:names].to_s.lines.map(&:squish).reject(&:blank?).first(25)
    return redirect_to(@household, alert: "Type at least one name, one per line.") if lines.empty?
    default_last = params[:default_last].to_s.squish.presence
    kids = params[:children] == "1"
    made = []
    Person.transaction do
      lines.each do |line|
        first, *rest = line.split(" ")
        last = rest.join(" ").presence || default_last
        made << current_family.people.create!(first_name: first, last_name: last, household: @household, hide_details: kids,
                                              created_by_id: current_user.id, updated_by_id: current_user.id)
      end
    end
    redirect_to @household, notice: "Added #{made.size} #{'person'.pluralize(made.size)}: #{made.map(&:display_name).to_sentence}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @household, alert: "Nobody was added. #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def load = @household = current_family.households.find(params[:id])
end
