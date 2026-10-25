require "test_helper"

class BoardTest < ActionDispatch::IntegrationTest
  test "topics, replies and plain-text rendering" do
    a, b = make_user(name: "Ann"), make_user(name: "Bo")
    sign_in a
    post board_path, params: { board_post: { title: "Cookout host?", body: "Who has a big yard?" } }
    t = BoardPost.topics.last
    assert_redirected_to board_topic_path(t)
    sign_in b
    get board_path
    assert_match(/1 new/, response.body)
    post board_replies_path(t), params: { board_post: { body: "<script>alert(1)</script> We do." } }
    get board_topic_path(t)
    assert_no_match(/<script>alert\(1\)/, response.body)
    assert_match(/We do\./, response.body)
  end

  test "empty title is rejected and nothing is saved" do
    sign_in make_user
    assert_no_difference "BoardPost.count" do
      post board_path, params: { board_post: { title: "", body: "x" } }
    end
    assert_response :unprocessable_entity
  end

  test "members cannot remove each other's posts; the admin can" do
    a, b = make_user, make_user
    t = a.board_posts.create!(title: "T", body: "b")
    sign_in b
    delete board_post_path(t)
    assert BoardPost.exists?(t.id)
    sign_in make_user(admin: true)
    delete board_post_path(t)
    assert_not BoardPost.exists?(t.id)
  end

  test "the new badge clears after visiting the board" do
    a, b = make_user, make_user
    a.board_posts.create!(title: "T", body: "b")
    sign_in b
    get root_path
    assert_match(/1 new/, response.body)
    get board_path
    get root_path
    assert_no_match(/\d+ new/, response.body)
  end
end
