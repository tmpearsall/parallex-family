class InvitationMailer < ApplicationMailer
  # params: invitation, url (the one-time link, never stored), inviter (User or nil)
  def invite
    @invitation = params[:invitation]
    @family = @invitation.family
    @url = params[:url]
    @inviter = params[:inviter]
    who = @inviter&.label || "A family organizer"
    mail(to: @invitation.email, reply_to: @inviter&.email, subject: "#{who} invited you to #{@family.name}")
  end
end
