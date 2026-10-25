# A unit that is invited and answers together: a family at one address.
class Household < ApplicationRecord
  has_many :people, dependent: :nullify
  has_many :rsvps, dependent: :destroy
  validates :name, presence: true, length: { maximum: 80 }
  before_validation { self.name = name.to_s.squish; self.city = city.to_s.squish.presence; self.region = region.to_s.squish.presence }

  def place = [ city, region ].compact.join(", ").presence
end
