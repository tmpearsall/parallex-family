# A short questionnaire an organizer mails to the family (see CreateSurveys for the shape of the data).
class Survey < ApplicationRecord
  STATUSES = %w[draft open closed].freeze
  MAX_QUESTIONS = 8

  belongs_to :family
  belongs_to :created_by, class_name: "User"
  belongs_to :reunion, optional: true
  has_many :questions, -> { order(:position, :id) }, class_name: "SurveyQuestion", dependent: :destroy
  has_many :recipients, class_name: "SurveyRecipient", dependent: :destroy
  has_many :responses, class_name: "SurveyResponse", dependent: :destroy

  validates :title, presence: true, length: { maximum: 120 }
  validates :intro, length: { maximum: 2000 }
  validates :status, inclusion: { in: STATUSES }
  validate :reunion_in_family
  before_validation { self.title = title.to_s.squish }

  def draft? = status == "draft"
  def closed? = status == "closed" || (closes_on.present? && closes_on < Date.current)
  def accepting? = status == "open" && !closed?

  def response_count = responses.count
  def sent_count = recipients.where.not(sent_at: nil).count

  private

  def reunion_in_family
    errors.add(:reunion, "belongs to a different group") if reunion && reunion.family_id != family_id
  end
end
