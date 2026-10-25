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
    @organizers = current_family.memberships.where(role: "organizer").includes(:user).map { |m| m.user.label }.reject { |n| n == "A member" }.uniq
    @steps = getting_started_steps
    @topics = current_family.board_posts.topics.includes(:user).order(created_at: :desc).limit(5)
  end

  private

  # The first things a new member should do, each ticked off from what is already on file. The card disappears
  # when every step is done.
  def getting_started_steps
    me = current_membership.person
    steps = []
    steps << { done: current_family.people.count >= 2, text: "Add the people you know", hint: "Start here: everything else hangs off the list of people. A first name is enough.", path: new_person_path, link: "Add a person" }
    steps << { done: me.present?, text: "Find yourself in the list", hint: "Open your name under People and press \"This is me\" so the site knows who you are.", path: people_path, link: "Open People" }
    if me
      steps << { done: (me.phone.present? || me.email.present?) && me.mailing_address?, text: "Add your phone and mailing address", hint: "Edit your own page; the mailing address can be a campus box or anywhere you get mail.", path: edit_person_path(me), link: "Edit my information" }
    end
    if @reunion && @my_household
      steps << { done: @my_rsvp.present?, text: "Answer the RSVP for #{@reunion.title}", hint: "One answer for your whole #{terms.party}.", path: reunion_path(@reunion) + "#rsvp", link: "RSVP" }
    end
    if @reunion && @reunion.date_options.any?
      steps << { done: @unvoted.empty?, text: "Vote on the proposed dates", hint: "Say which dates work for you.", path: reunion_path(@reunion) + "#dates", link: "Vote" }
    end
    steps
  end
end
