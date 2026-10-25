# One organizer's message to one member. Carries the same unsubscribe link and one-click header as the digest.
class AnnouncementMailer < ApplicationMailer
  # params: membership, announcement
  def note
    @membership = params[:membership]
    @announcement = params[:announcement]
    @family = @membership.family
    @sender = @announcement.user.label
    @unsubscribe_url = unsubscribe_url(token: @membership.unsubscribe_token!)
    @home_url = family_home_url(family: @family.slug)
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    mail(from: from_for(@family), to: @membership.user.email, subject: @announcement.subject || "A message from #{@sender} in #{@family.name}")
  end
end
