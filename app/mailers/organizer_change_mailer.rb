# A plain notice to every organizer when who organizes changes. Not a reminder, so it has no unsubscribe link.
class OrganizerChangeMailer < ApplicationMailer
  def notice
    @membership = params[:membership]
    @event = params[:event]
    @family = @membership.family
    @admin_url = members_url(family: @family.slug)
    mail(from: from_for(@family), to: @membership.user.email, subject: "A change to who organizes #{@family.name}")
  end
end
