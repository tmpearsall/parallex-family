require "test_helper"

# Two families, one signed-in member of the first. Nothing of the second may be read or changed by guessing ids.
class IsolationTest < ActionDispatch::IntegrationTest
  setup do
    @a = make_family("Rowe")
    @b = make_family("Lee")
    @user = member(fam: @a, role: "organizer")
    @bperson = make_person("Zed", "Lee", fam: @b)
    @bperson2 = make_person("Yul", "Lee", fam: @b)
    @brel = link(@bperson, @bperson2)
    @bhouse = Household.create!(family: @b, name: "The Lees")
    @breunion = Reunion.create!(family: @b, title: "Lee reunion", starts_on: "2027-07-02")
    @bopt = @breunion.date_options.create!(starts_on: "2027-07-02")
    @btask = @breunion.tasks.create!(title: "Grill")
    @btopic = BoardPost.create!(family: @b, user: member(fam: @b), title: "Lee topic", body: "secret plans")
    sign_in @user
    get family_home_path(family: @a.slug)   # a first successful request establishes the session cookie
    assert_response :success
  end

  test "another family's data is not reachable through its own family path" do
    [ person_path(@bperson, family: @b.slug), households_path(family: @b.slug), reunion_path(@breunion, family: @b.slug), board_topic_path(@btopic, family: @b.slug) ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "guessing another family's ids under my own family path finds nothing" do
    get person_path(@bperson, family: @a.slug)
    assert_response :not_found
    get household_path(@bhouse, family: @a.slug)
    assert_response :not_found
    get reunion_path(@breunion, family: @a.slug)
    assert_response :not_found
    get board_topic_path(@btopic, family: @a.slug)
    assert_response :not_found
    get edit_person_path(@bperson, family: @a.slug)
    assert_response :not_found
  end

  test "changes to another family's records are refused and nothing changes" do
    patch person_path(@bperson, family: @a.slug), params: { person: { first_name: "Hacked" } }
    assert_response :not_found
    assert_equal "Zed", @bperson.reload.first_name
    delete person_path(@bperson, family: @a.slug)
    assert Person.exists?(@bperson.id)
    delete relationship_path(@brel, family: @a.slug)
    assert Relationship.exists?(@brel.id)
    delete board_post_path(@btopic, family: @a.slug)
    assert BoardPost.exists?(@btopic.id)
    patch claim_reunion_task_path(@breunion, @btask, family: @a.slug)
    assert_nil @btask.reload.claimed_by_id
    post vote_reunion_date_option_path(@breunion, @bopt, family: @a.slug, answer: "yes")
    assert_equal 0, @bopt.date_votes.count
  end

  test "an RSVP cannot name another family's household or reunion" do
    mine = Reunion.create!(family: @a, title: "Rowe reunion")
    post reunion_rsvps_path(mine, family: @a.slug), params: { rsvp: { household_id: @bhouse.id, status: "maybe" } }
    assert_response :not_found
    assert_equal 0, Rsvp.count
    post reunion_rsvps_path(@breunion, family: @a.slug), params: { rsvp: { household_id: Household.create!(family: @a, name: "Mine").id, status: "maybe" } }
    assert_response :not_found
  end

  test "a person cannot be linked to someone in another family" do
    mine = make_person("Ann", fam: @a)
    post person_relationships_path(mine, family: @a.slug), params: { relationship: { as: "child", other_id: @bperson.id } }
    assert_redirected_to person_path(mine, family: @a.slug)
    assert_equal 0, Relationship.where(family_id: @a.id).count
  end

  test "a new person cannot be put in another family's household" do
    assert_no_difference "Person.count" do
      post people_path(family: @a.slug), params: { person: { first_name: "Sam", household_id: @bhouse.id } }
    end
    assert_response :unprocessable_entity
  end

  test "the tree, people list and board show only my family" do
    make_person("Ann", fam: @a)
    get tree_path(family: @a.slug)
    assert_no_match(/Zed|Yul/, response.body)
    get people_path(family: @a.slug)
    assert_match(/Ann/, response.body)
    assert_no_match(/Zed|Yul/, response.body)
    get board_path(family: @a.slug)
    assert_no_match(/Lee topic|secret plans/, response.body)
  end

  test "a membership in both families sees each separately" do
    both = make_user
    Membership.create!(family: @a, user: both, role: "member")
    Membership.create!(family: @b, user: both, role: "member")
    sign_in both
    get people_path(family: @b.slug)
    assert_match(/Zed/, response.body)
    get people_path(family: @a.slug)
    assert_no_match(/Zed/, response.body)
  end
end
