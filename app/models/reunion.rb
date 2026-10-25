class Reunion < ApplicationRecord
  belongs_to :family
  has_many :date_options, -> { order(:starts_on) }, dependent: :destroy
  has_many :rsvps, dependent: :destroy
  has_many :tasks, -> { order(:done, :created_at) }, dependent: :destroy
  has_many :board_posts, dependent: :nullify

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 4000 }
  validates :location_name, :address, length: { maximum: 200 }
  validate  :dates_in_order
  before_validation { self.title = title.to_s.squish }

  scope :upcoming_first, -> { order(Arel.sql("coalesce(starts_on, date '9999-12-31')"), :created_at) }

  def dated? = starts_on.present?

  # Headcounts from RSVPs, by status. Households that have not answered are not counted.
  def headcount
    attending = rsvps.where(status: "attending")
    { households: attending.count, adults: attending.sum(:adults), children: attending.sum(:children),
      maybe_households: rsvps.where(status: "maybe").count, declined: rsvps.where(status: "not_attending").count }
  end

  private

  def dates_in_order
    errors.add(:ends_on, "is before the start") if starts_on && ends_on && ends_on < starts_on
  end
end
