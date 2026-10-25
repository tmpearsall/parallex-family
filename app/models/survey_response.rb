class SurveyResponse < ApplicationRecord
  belongs_to :survey
  belongs_to :survey_recipient
  has_many :answers, class_name: "SurveyAnswer", dependent: :destroy
end
