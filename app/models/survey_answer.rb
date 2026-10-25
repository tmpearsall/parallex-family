class SurveyAnswer < ApplicationRecord
  belongs_to :survey_response
  belongs_to :survey_question
  validates :body, length: { maximum: 2000 }
end
