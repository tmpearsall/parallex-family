# The family message board: planning questions, ideas, and anything the group should see.
class BoardController < ApplicationController
  before_action :load_topic, only: %i[show reply destroy pin]
  after_action :mark_seen, only: :index

  def index
    @seen   = current_user.board_seen_at
    @topics = topic_list
    @topic  = BoardPost.new(reunion_id: params[:reunion_id].presence)
  end

  def create
    @topic = current_user.board_posts.new(params.require(:board_post).permit(:title, :body, :reunion_id))
    if @topic.save
      redirect_to board_topic_path(@topic), notice: "Posted."
    else
      @seen = current_user.board_seen_at
      @topics = topic_list
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @replies = @topic.replies.includes(:user)
    @reply   = BoardPost.new
  end

  def reply
    @reply = current_user.board_posts.new(params.require(:board_post).permit(:body).merge(parent_id: @topic.id))
    if @reply.save
      redirect_to board_topic_path(@topic, anchor: "r#{@reply.id}"), notice: "Reply posted."
    else
      @replies = @topic.replies.includes(:user)
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    post = BoardPost.find(params[:id])
    if post.removable_by?(current_user)
      post.destroy
      redirect_to(post.parent_id ? board_topic_path(post.parent_id) : board_path, notice: "Removed.")
    else
      redirect_to board_path, alert: "That post is locked. Ask the administrator to remove it."
    end
  end

  def pin
    return head(:forbidden) unless current_user.admin?
    @topic.update!(pinned: !@topic.pinned)
    redirect_to board_path, notice: (@topic.pinned ? "Pinned." : "Unpinned.")
  end

  private

  def mark_seen = current_user.update_columns(board_seen_at: Time.current)

  def topic_list
    BoardPost.topics.includes(:user, :reunion)
             .select("board_posts.*, (select count(*) from board_posts r where r.parent_id = board_posts.id) as reply_count, " \
                     "coalesce((select max(r.created_at) from board_posts r where r.parent_id = board_posts.id), board_posts.created_at) as last_activity")
             .order(pinned: :desc).order(Arel.sql("last_activity desc")).limit(200)
  end

  def load_topic
    @topic = BoardPost.find(params[:id])
    @topic = @topic.parent if @topic.parent_id && action_name != "destroy"
  end
end
