class HomeController < TenantController
  def show
    @reunion = current_family.reunions.upcoming_first.first
    if @reunion
      @headcount = @reunion.headcount
      @open_tasks = @reunion.tasks.where(done: false).limit(6)
      @my_household = current_membership.person&.household
      @my_rsvp = @reunion.rsvps.find_by(household: @my_household) if @my_household
      voted = current_user.date_votes.pluck(:date_option_id)
      @unvoted = @reunion.date_options.reject { |o| voted.include?(o.id) }
    end
    @topics = current_family.board_posts.topics.includes(:user).order(created_at: :desc).limit(5)
  end
end
