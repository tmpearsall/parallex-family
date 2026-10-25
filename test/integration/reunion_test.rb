require "test_helper"

class ReunionTest < ActionDispatch::IntegrationTest
  setup do
    @admin = make_user(admin: true)
    @reunion = Reunion.create!(title: "Rowe reunion", starts_on: "2027-07-02")
    @h = Household.create!(name: "The Rowes")
  end

  test "a member can RSVP for a household and the counts show" do
    sign_in make_user
    post reunion_rsvps_path(@reunion), params: { rsvp: { household_id: @h.id, status: "attending", adults: 2, children: 1, dietary: "vegetarian", lodging_needed: "1" } }
    assert_redirected_to reunion_path(@reunion)
    assert_equal 3, @reunion.headcount[:adults] + @reunion.headcount[:children]
    get reunion_path(@reunion)
    assert_match(/vegetarian/, response.body)
  end

  test "answering again updates the same RSVP" do
    sign_in make_user
    2.times { |i| post reunion_rsvps_path(@reunion), params: { rsvp: { household_id: @h.id, status: "attending", adults: i + 1 } } }
    assert_equal 1, @reunion.rsvps.count
    assert_equal 2, @reunion.rsvps.first.adults
  end

  test "only an admin proposes dates; anyone can vote and change a vote" do
    u = make_user
    sign_in u
    post reunion_date_options_path(@reunion), params: { date_option: { starts_on: "2027-07-02" } }
    assert_response :forbidden
    sign_in @admin
    post reunion_date_options_path(@reunion), params: { date_option: { starts_on: "2027-07-02" } }
    opt = @reunion.date_options.first
    sign_in u
    post vote_reunion_date_option_path(@reunion, opt, answer: "yes")
    post vote_reunion_date_option_path(@reunion, opt, answer: "no")
    assert_equal 1, opt.date_votes.count
    assert_equal "no", opt.date_votes.first.answer
    post vote_reunion_date_option_path(@reunion, opt, answer: "bogus")
    assert_equal "no", opt.date_votes.first.reload.answer
  end

  test "tasks can be claimed, finished and released" do
    u = make_user
    sign_in u
    post reunion_tasks_path(@reunion), params: { task: { title: "Bring a grill" } }
    t = @reunion.tasks.first
    patch claim_reunion_task_path(@reunion, t)
    assert_equal u.id, t.reload.claimed_by_id
    patch toggle_reunion_task_path(@reunion, t)
    assert t.reload.done
    patch unclaim_reunion_task_path(@reunion, t)
    assert_nil t.reload.claimed_by_id
  end

  test "only an admin creates reunions" do
    sign_in make_user
    post reunions_path, params: { reunion: { title: "Another" } }
    assert_response :forbidden
  end
end
