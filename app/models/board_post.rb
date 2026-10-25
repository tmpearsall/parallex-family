# The family message board. A topic (parent_id nil, with a title) starts a thread; a reply (parent_id set) is
# plain text under it. Members see each other's display names, never emails. The administrator can pin and
# delete anything; an author can delete their own for 48 hours.
class BoardPost < ApplicationRecord
  EDIT_WINDOW = 48.hours

  belongs_to :family
  belongs_to :user
  belongs_to :parent, class_name: "BoardPost", optional: true
  belongs_to :reunion, optional: true
  has_many :replies, -> { order(:created_at) }, class_name: "BoardPost", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true, length: { maximum: 4000 }
  validates :title, presence: true, length: { maximum: 120 }, if: :topic?
  validate  :reply_goes_under_a_topic
  validate  :reunion_is_in_this_family

  before_validation do
    self.family_id ||= parent&.family_id
    self.title = title.to_s.squish.presence
    self.body  = body.to_s.strip
    if parent_id.present?
      self.title = nil
      self.pinned = false
    end
  end

  scope :topics, -> { where(parent_id: nil) }

  def topic? = parent_id.nil?
  def removable_by?(membership) = membership.organizer? || (user_id == membership.user_id && created_at > EDIT_WINDOW.ago)

  private

  def reunion_is_in_this_family
    errors.add(:reunion, "belongs to a different family") if reunion && reunion.family_id != family_id
  end

  def reply_goes_under_a_topic
    errors.add(:base, "Replies go under a topic.") if parent && !parent.topic?
    errors.add(:base, "Replies stay in the same family.") if parent && parent.family_id != family_id
  end
end
