# Someone who asked not to be sent surveys for this family. Applies to anyone on the list, with or without an account.
class SurveyOptOut < ApplicationRecord
  belongs_to :family
  before_validation { self.email = email.to_s.strip.downcase }
  validates :email, presence: true
end
