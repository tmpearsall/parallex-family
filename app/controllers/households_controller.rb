class HouseholdsController < TenantController
  before_action :load, only: %i[show edit update]

  def index = @households = current_family.households.includes(:people).order(:name)
  def show = @members = @household.people.by_name
  def new = @household = current_family.households.new

  def create
    @household = current_family.households.new(params.require(:household).permit(:name, :city, :region, :notes))
    @household.save ? redirect_to(@household, notice: "Household added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @household.update(params.require(:household).permit(:name, :city, :region, :notes)) ? redirect_to(@household, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  private

  def load = @household = current_family.households.find(params[:id])
end
