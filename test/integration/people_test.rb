require "test_helper"

class PeopleTest < ActionDispatch::IntegrationTest
  setup { sign_in make_user }

  test "adding a child from a parent's page links them" do
    parent = make_person("Ann")
    post people_path, params: { person: { first_name: "Cy", last_name: "Rowe" }, relate_to: parent.id, as: "child" }
    assert_redirected_to person_path(parent)
    assert_equal [ "Cy" ], parent.children.map(&:first_name)
  end

  test "an invalid new person is not saved" do
    ann = make_person("Ann"); cy = make_person("Cy"); link(ann, cy)
    assert_no_difference "Person.count" do
      post people_path, params: { person: { first_name: "" }, relate_to: ann.id, as: "child" }
    end
    assert_response :unprocessable_entity
  end

  test "only an administrator lifts a child's privacy" do
    kid = make_person("Kid", hide_details: true)
    patch person_path(kid), params: { person: { first_name: "Kid", hide_details: "0" } }
    assert kid.reload.hide_details
    sign_in make_user(admin: true)
    patch person_path(kid), params: { person: { first_name: "Kid", hide_details: "0" } }
    assert_not kid.reload.hide_details
  end

  test "private details of a child are hidden from other members" do
    kid = make_person("Kid", hide_details: true, birth_date: "2014-02-02", notes: "allergic to nuts", email: "kid@example.test")
    get person_path(kid)
    assert_response :success
    assert_no_match(/2014/, response.body)
    assert_no_match(/allergic/, response.body)
    assert_no_match(/kid@example/, response.body)
    assert_match(/Details kept private/, response.body)
  end

  test "an admin sees a child's details, and only an admin can delete" do
    kid = make_person("Kid", hide_details: true, notes: "allergic to nuts")
    sign_in make_user(admin: true)
    get person_path(kid)
    assert_match(/allergic/, response.body)
    assert_difference "Person.count", -1 do
      delete person_path(kid)
    end
  end

  test "a member cannot delete people" do
    p = make_person("Ann")
    delete person_path(p)
    assert_response :forbidden
    assert Person.exists?(p.id)
  end

  test "privacy is off unless asked for" do
    post people_path, params: { person: { first_name: "Sam", hide_details: "0" } }
    assert_not Person.find_by(first_name: "Sam").hide_details
  end
end
