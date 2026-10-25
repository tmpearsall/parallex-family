class CalendarController < TenantController
  def index
    @month = parse_month(params[:month])
    @first = @month.beginning_of_month
    @last  = @month.end_of_month
    grid_from = @first.beginning_of_week(:sunday)
    grid_to   = @last.end_of_week(:sunday)
    @items = CalendarItems.new(family: current_family, membership: current_membership).between(grid_from, grid_to)
    @weeks = (grid_from..grid_to).each_slice(7).to_a
    @agenda = @items.select { |i| i.last_day >= @first && i.on <= @last }
    @feed_url = "#{request.base_url}/calendar/#{current_membership.calendar_token!}.ics"
  end

  def reset_link
    current_membership.reset_calendar_token!
    redirect_to calendar_path, notice: "New subscription address made. The old one stopped working."
  end

  private

  def parse_month(raw)
    Date.strptime(raw.to_s, "%Y-%m")
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end
