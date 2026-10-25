class HouseholdsController < ApplicationController
  before_action :load, only: %i[show edit update]

  def index = @households = Household.includes(:people).order(:name)
  def show = @members = @household.people.by_name
  def new = @household = Household.new

  def create
    @household = Household.new(params.require(:household).permit(:name, :city, :region, :notes))
    @household.save ? redirect_to(@household, notice: "Household added.") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @household.update(params.require(:household).permit(:name, :city, :region, :notes)) ? redirect_to(@household, notice: "Saved.") : render(:edit, status: :unprocessable_entity)
  end

  private

  def load = @household = Household.find(params[:id])
end
