require "test_helper"

class InviteNewPersonTest < ActionDispatch::IntegrationTest
  setup do
    @family = Family.create!(name: "Invite Test", slug: "invite-test")
    @org = User.create!(email: "org@example.test", password: "Str0ng!Pass#1", name: "Org")
    @me = @family.people.create!(first_name: "Thea", last_name: "Test")
    @family.memberships.create!(user: @org, role: "organizer", person: @me)
    post user_session_path, params: { user: { email: @org.email, password: "Str0ng!Pass#1" } }
  end

  test "an organizer adds a person who is not in the list and records the child link" do
    assert_difference [ "Person.count", "Relationship.count", "Invitation.count" ], 1 do
      post "/f/invite-test/members", params: { invite: { emails: "hawthorne@example.test", role: "member", send_email: "0",
        new_first_name: "Hawthorne", new_last_name: "Test", relation: "child", related_to_id: @me.id } }
    end
    assert_response :success
    kid = @family.people.find_by!(first_name: "Hawthorne")
    assert_equal "hawthorne@example.test", kid.email
    assert_equal [ @me.id ], kid.parents.pluck(:id)
    assert_equal kid.id, Invitation.order(:id).last.person_id
  end

  test "no relation recorded still creates the person and the invitation" do
    assert_no_difference "Relationship.count" do
      post "/f/invite-test/members", params: { invite: { emails: "cousin@example.test", role: "member", send_email: "0", new_first_name: "Cora", relation: "" } }
    end
    assert @family.people.exists?(first_name: "Cora")
  end

  test "a bad new person stops the invite and says why" do
    assert_no_difference [ "Person.count", "Invitation.count" ] do
      post "/f/invite-test/members", params: { invite: { emails: "bad@example.test", role: "member", new_first_name: "A" * 200 } }
    end
    assert_redirected_to "/f/invite-test/members"
  end

  test "the form offers the add-them fields" do
    get "/f/invite-test/members"
    assert_includes response.body, "Not in the list? Add them here"
  end
end
