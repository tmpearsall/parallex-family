class DateVote < ApplicationRecord
  ANSWERS = %w[yes maybe no].freeze
  belongs_to :date_option
  belongs_to :user
  validates :answer, inclusion: { in: ANSWERS }
  validates :user_id, uniqueness: { scope: :date_option_id }
end
