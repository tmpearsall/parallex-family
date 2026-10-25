# One digest per member per run: everything due for them today, in one message. Never carries a child's
# private details; it only repeats what the member could see on the site.
class ReminderMailer < ApplicationMailer
  # params: membership, items (array of ReminderRunner::Item)
  def digest
    @membership = params[:membership]
    @family = @membership.family
    @items = params[:items]
    @unsubscribe_url = unsubscribe_url(token: @membership.unsubscribe_token!)
    @home_url = family_home_url(family: @family.slug)
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    subject = @items.size == 1 ? @items.first.headline : "#{@items.size} reminders for #{@family.name}"
    mail(to: @membership.user.email, subject: subject)
  end
end
