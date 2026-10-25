class TasksController < TenantController
  before_action :load

  def create
    t = @reunion.tasks.new(params.require(:task).permit(:title, :details))
    t.save ? redirect_to(@reunion, notice: "Added.") : redirect_to(@reunion, alert: t.errors.full_messages.to_sentence)
  end

  def claim   = update_task(claimed_by: current_user, notice: "It's yours.")
  def unclaim = update_task(claimed_by: nil, notice: "Released.")
  def toggle  = update_task(done: !@task.done, notice: "Updated.")

  def destroy
    return head(:forbidden) unless organizer? || @task.claimed_by_id == current_user.id || @task.claimed_by_id.nil?
    @task.destroy
    redirect_to @reunion, notice: "Removed."
  end

  private

  def load
    @reunion = current_family.reunions.find(params[:reunion_id])
    @task = @reunion.tasks.find(params[:id]) if params[:id]
  end

  def update_task(attrs)
    notice = attrs.delete(:notice)
    @task.update!(attrs)
    redirect_to @reunion, notice: notice
  end
end
