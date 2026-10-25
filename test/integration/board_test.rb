require "test_helper"

class BoardTest < ActionDispatch::IntegrationTest
  setup { @f = family.slug }

  test "topics, replies and plain-text rendering" do
    a, b = member(name: "Ann"), member(name: "Bo")
    sign_in a
    post board_path(family: @f), params: { board_post: { title: "Cookout host?", body: "Who has a big yard?" } }
    t = family.board_posts.topics.last
    assert_redirected_to board_topic_path(t, family: @f)
    sign_in b
    get family_home_path(family: @f)
    assert_match(/1 new/, response.body)
    post board_replies_path(t, family: @f), params: { board_post: { body: "<script>alert(1)</script> We do." } }
    get board_topic_path(t, family: @f)
    assert_no_match(/<script>alert\(1\)/, response.body)
    assert_match(/We do\./, response.body)
  end

  test "empty title is rejected and nothing is saved" do
    sign_in member
    assert_no_difference "BoardPost.count" do
      post board_path(family: @f), params: { board_post: { title: "", body: "x" } }
    end
    assert_response :unprocessable_entity
  end

  test "members cannot remove each other's posts; an organizer can" do
    a, b = member, member
    t = BoardPost.create!(family: family, user: a, title: "T", body: "b")
    sign_in b
    delete board_post_path(t, family: @f)
    assert BoardPost.exists?(t.id)
    sign_in member(role: "organizer")
    delete board_post_path(t, family: @f)
    assert_not BoardPost.exists?(t.id)
  end

  test "the new badge clears after visiting the board, per family" do
    a, b = member, member
    BoardPost.create!(family: family, user: a, title: "T", body: "b")
    sign_in b
    get family_home_path(family: @f)
    assert_match(/1 new/, response.body)
    get board_path(family: @f)
    get family_home_path(family: @f)
    assert_no_match(/\d+ new/, response.body)
  end

  test "only organizers pin" do
    t = BoardPost.create!(family: family, user: member, title: "T", body: "b")
    sign_in member
    patch board_pin_path(t, family: @f)
    assert_response :forbidden
    sign_in member(role: "organizer")
    patch board_pin_path(t, family: @f)
    assert t.reload.pinned
  end
end
