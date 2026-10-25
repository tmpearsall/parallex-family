class ReunionsController < ApplicationController
  before_action :load, only: %i[show edit update]
  before_action :admin_only!, only: %i[new create edit update]

  def index = @reunions = Reunion.upcoming_first

  def show
    @headcount = @reunion.headcount
    @households = Household.order(:name)
    @rsvps = @reunion.rsvps.includes(:household).index_by(&:household_id)
    @waiting = @households.reject { |h| @rsvps.key?(h.id) }
    @my_household = current_user.person&.household
    @my_votes = current_user.date_votes.where(date_option_id: @reunion.date_options.select(:id)).index_by(&:date_option_id)
    @tasks = @reunion.tasks.includes(:claimed_by)
    @topics = @reunion.board_posts.topics.order(created_at: :desc).limit(5)
  end

  def new = @reunion = Reunion.new

  def create
    @reunion = Reunion.new(reunion_params.merge(created_by_id: current_user.id))
    @reunion.save ? redirect_to(@reunion, notice: "Reunion created.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @reunion.update(reunion_params) ? redirect_to(@reunion, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  private

  def load = @reunion = Reunion.find(params[:id])
  def reunion_params = params.require(:reunion).permit(:title, :starts_on, :ends_on, :location_name, :address, :description, :rsvp_by)
end
