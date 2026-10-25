require "test_helper"

class ReunionTest < ActionDispatch::IntegrationTest
  setup do
    @boss = member(role: "organizer")
    @reunion = Reunion.create!(family: family, title: "Rowe reunion", starts_on: "2027-07-02")
    @h = Household.create!(family: family, name: "The Rowes")
    @f = family.slug
  end

  test "a member can RSVP for a household and the counts show" do
    sign_in member
    post reunion_rsvps_path(@reunion, family: @f), params: { rsvp: { household_id: @h.id, status: "attending", adults: 2, children: 1, dietary: "vegetarian", lodging_needed: "1" } }
    assert_redirected_to reunion_path(@reunion, family: @f)
    assert_equal 3, @reunion.headcount[:adults] + @reunion.headcount[:children]
    get reunion_path(@reunion, family: @f)
    assert_match(/vegetarian/, response.body)
  end

  test "answering again updates the same RSVP" do
    sign_in member
    2.times { |i| post reunion_rsvps_path(@reunion, family: @f), params: { rsvp: { household_id: @h.id, status: "attending", adults: i + 1 } } }
    assert_equal 1, @reunion.rsvps.count
    assert_equal 2, @reunion.rsvps.first.adults
  end

  test "only an organizer proposes dates; anyone can vote and change a vote" do
    u = member
    sign_in u
    post reunion_date_options_path(@reunion, family: @f), params: { date_option: { starts_on: "2027-07-02" } }
    assert_response :forbidden
    sign_in @boss
    post reunion_date_options_path(@reunion, family: @f), params: { date_option: { starts_on: "2027-07-02" } }
    opt = @reunion.date_options.first
    sign_in u
    post vote_reunion_date_option_path(@reunion, opt, family: @f, answer: "yes")
    post vote_reunion_date_option_path(@reunion, opt, family: @f, answer: "no")
    assert_equal 1, opt.date_votes.count
    assert_equal "no", opt.date_votes.first.answer
    post vote_reunion_date_option_path(@reunion, opt, family: @f, answer: "bogus")
    assert_equal "no", opt.date_votes.first.reload.answer
  end

  test "tasks can be claimed, finished and released" do
    u = member
    sign_in u
    post reunion_tasks_path(@reunion, family: @f), params: { task: { title: "Bring a grill" } }
    t = @reunion.tasks.first
    patch claim_reunion_task_path(@reunion, t, family: @f)
    assert_equal u.id, t.reload.claimed_by_id
    patch toggle_reunion_task_path(@reunion, t, family: @f)
    assert t.reload.done
    patch unclaim_reunion_task_path(@reunion, t, family: @f)
    assert_nil t.reload.claimed_by_id
  end

  test "only an organizer creates reunions" do
    sign_in member
    post reunions_path(family: @f), params: { reunion: { title: "Another" } }
    assert_response :forbidden
    sign_in @boss
    assert_difference "Reunion.count", 1 do
      post reunions_path(family: @f), params: { reunion: { title: "Another" } }
    end
    assert_equal family.id, Reunion.order(:id).last.family_id
  end
end
