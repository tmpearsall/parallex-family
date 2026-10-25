# Something the reunion needs: a dish, a venue call, a playlist. Anyone can claim it.
class Task < ApplicationRecord
  belongs_to :reunion
  belongs_to :claimed_by, class_name: "User", optional: true
  validates :title, presence: true, length: { maximum: 120 }
  validates :details, length: { maximum: 1000 }
  before_validation { self.title = title.to_s.squish }
end
