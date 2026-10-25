# The trail for who organizes: who did what to whom, and when.
class MembershipEvent < ApplicationRecord
  KINDS = %w[invited_organizer made_organizer made_member removed_organizer ownership_transferred].freeze
  belongs_to :family
  belongs_to :actor_user, class_name: "User", optional: true
  validates :kind, inclusion: { in: KINDS }
  validates :target_label, presence: true

  def sentence
    who = actor_user&.label || "Someone"
    case kind
    when "invited_organizer" then "#{who} invited #{target_label} as an organizer"
    when "made_organizer" then "#{who} made #{target_label} an organizer"
    when "made_member" then "#{who} made #{target_label} a member"
    when "removed_organizer" then "#{who} removed organizer #{target_label}"
    when "ownership_transferred" then "#{who} made #{target_label} the owner"
    end
  end

  # Records the change and tells every organizer (the actor included, as confirmation of what was logged).
  def self.record!(family:, actor:, kind:, target:)
    ev = create!(family: family, actor_user: actor, kind: kind, target_label: target)
    family.memberships.where(role: "organizer").includes(:user).find_each do |m|
      OrganizerChangeMailer.with(membership: m, event: ev).notice.deliver_now
    rescue StandardError => e
      Rails.logger.error("organizer notice failed for membership #{m.id}: #{e.class}: #{e.message}")
    end
    ev
  end
end
