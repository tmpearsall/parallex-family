class DateOption < ApplicationRecord
  belongs_to :reunion
  has_many :date_votes, dependent: :destroy
  validates :starts_on, presence: true
  validates :note, length: { maximum: 200 }
  validate { errors.add(:ends_on, "is before the start") if starts_on && ends_on && ends_on < starts_on }

  def tally = date_votes.group(:answer).count.reverse_merge("yes" => 0, "maybe" => 0, "no" => 0)
  def score = tally["yes"] * 2 + tally["maybe"]
end
