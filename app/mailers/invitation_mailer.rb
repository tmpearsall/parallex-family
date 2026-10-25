class InvitationMailer < ApplicationMailer
  # params: invitation, url (the one-time link, never stored), inviter (User or nil)
  def invite
    @invitation = params[:invitation]
    @family = @invitation.family
    @url = params[:url]
    @inviter = params[:inviter]
    # An account whose display name is just the site's name tells the reader nothing about who is behind it.
    label = @inviter&.label
    @sender = label if label.present? && label.casecmp?(@family.name) == false && label != "A member"
    @organizers = @family.memberships.where(role: "organizer").includes(:user).map { |m| m.user.label }.reject { |n| n == "A member" }.uniq
    @reunion = @family.reunions.upcoming_first.first
    @role = @invitation.role
    mail(from: from_for(@family), to: @invitation.email, reply_to: @inviter&.email,
         subject: "#{@sender || 'An organizer'} invited you to #{@family.name}")
  end
end
