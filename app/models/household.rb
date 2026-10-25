# A unit that is invited and answers together: a family at one address.
class Household < ApplicationRecord
  belongs_to :family
  has_many :people, dependent: :nullify
  has_many :rsvps, dependent: :destroy
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  belongs_to :editor,  class_name: "User", foreign_key: :updated_by_id, optional: true
  validates :name, presence: true, length: { maximum: 80 }
  before_validation { self.name = name.to_s.squish; self.city = city.to_s.squish.presence; self.region = region.to_s.squish.presence }

  def place = [ city, region ].compact.join(", ").presence
end
