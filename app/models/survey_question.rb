class SurveyQuestion < ApplicationRecord
  KINDS = %w[single multi short long dates].freeze
  CHOICE_KINDS = %w[single multi].freeze
  MAX_OPTIONS = 12

  belongs_to :survey
  has_many :answers, class_name: "SurveyAnswer", dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :prompt, presence: true, length: { maximum: 200 }
  validate :options_fit_kind
  before_validation do
    self.prompt = prompt.to_s.squish
    self.options = Array(options).map { |o| o.to_s.squish }.reject(&:blank?).first(MAX_OPTIONS)
    self.options = [] unless CHOICE_KINDS.include?(kind)
  end

  def choice? = CHOICE_KINDS.include?(kind)
  def label = { "single" => "Pick one", "multi" => "Pick any", "short" => "Short answer", "long" => "Long answer", "dates" => "Suggest dates" }[kind]

  private

  def options_fit_kind
    return unless choice?
    errors.add(:options, "need at least two choices") if options.size < 2
    errors.add(:options, "are too long (120 characters each)") if options.any? { |o| o.length > 120 }
  end
end
