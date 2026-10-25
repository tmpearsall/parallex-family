class HomeController < ApplicationController
  def show
    @reunion  = Reunion.upcoming_first.first
    if @reunion
      @headcount = @reunion.headcount
      @open_tasks = @reunion.tasks.where(done: false).limit(6)
      @my_household = current_user.person&.household
      @my_rsvp = @reunion.rsvps.find_by(household: @my_household) if @my_household
      voted = current_user.date_votes.pluck(:date_option_id)
      @unvoted = @reunion.date_options.reject { |o| voted.include?(o.id) }
    end
    @topics = BoardPost.topics.includes(:user).order(created_at: :desc).limit(5)
  end
end
