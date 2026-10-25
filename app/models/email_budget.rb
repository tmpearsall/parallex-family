# One shared daily cap on organizer-initiated email per family (reminder messages and surveys), so a mistake cannot
# become a flood. Invitations have their own cap.
module EmailBudget
  DAILY_LIMIT = Announcement::DAILY_LIMIT

  def self.sent_today(family)
    since = 24.hours.ago
    Announcement.sent_today(family) +
      SurveyRecipient.joins(:survey).where(surveys: { family_id: family.id }).where("survey_recipients.sent_at > :t or survey_recipients.reminded_at > :t", t: since).count
  end

  def self.left(family) = [ DAILY_LIMIT - sent_today(family), 0 ].max
end
