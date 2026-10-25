# Public (token only): the iCalendar feed a phone or computer calendar app subscribes to.
class CalendarFeedsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    membership = Membership.includes(:family).find_by(calendar_token: params[:token])
    return head(:not_found) unless membership
    response.headers["Cache-Control"] = "private, max-age=0, no-store"
    send_data IcsFeed.new(family: membership.family, membership: membership).to_s,
              type: "text/calendar; charset=utf-8", disposition: "inline", filename: "#{membership.family.slug}.ics"
  end
end
