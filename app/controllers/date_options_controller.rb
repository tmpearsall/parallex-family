class DateOptionsController < ApplicationController
  before_action :admin_only!, only: %i[create destroy]
  before_action :load_reunion

  def create
    opt = @reunion.date_options.new(params.require(:date_option).permit(:starts_on, :ends_on, :note))
    opt.save ? redirect_to(@reunion, notice: "Date added.") : redirect_to(@reunion, alert: opt.errors.full_messages.to_sentence)
  end

  def destroy
    @reunion.date_options.find(params[:id]).destroy
    redirect_to @reunion, notice: "Date removed."
  end

  def vote
    opt = @reunion.date_options.find(params[:id])
    v = opt.date_votes.find_or_initialize_by(user: current_user)
    v.answer = params[:answer]
    v.save ? redirect_to(@reunion, notice: "Vote saved.") : redirect_to(@reunion, alert: "Pick yes, maybe or no.")
  end

  private

  def load_reunion = @reunion = Reunion.find(params[:reunion_id])
end
