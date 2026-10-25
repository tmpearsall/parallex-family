class Person < ApplicationRecord
  belongs_to :family
  belongs_to :household, optional: true
  has_many :child_links,  -> { parents },  class_name: "Relationship", foreign_key: :from_person_id, dependent: :destroy
  has_many :parent_links, -> { parents },  class_name: "Relationship", foreign_key: :to_person_id,   dependent: :destroy
  has_many :partner_out,  -> { partners }, class_name: "Relationship", foreign_key: :from_person_id, dependent: :destroy
  has_many :partner_in,   -> { partners }, class_name: "Relationship", foreign_key: :to_person_id,   dependent: :destroy
  has_many :memberships, dependent: :nullify

  validates :first_name, presence: true, length: { maximum: 80 }
  validates :last_name, :maiden_name, :nickname, :birth_place, :occupation, length: { maximum: 120 }
  validates :notes, length: { maximum: 4000 }
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/ }, allow_blank: true
  validate  :dates_in_order
  validate  :household_is_in_this_family

  before_validation do
    %i[first_name last_name maiden_name nickname birth_place occupation email].each { |a| self[a] = self[a].to_s.squish.presence }
  end

  scope :by_name, -> { order(Arel.sql("lower(coalesce(last_name,'')), lower(first_name)")) }

  def living? = death_date.nil?
  def display_name = [ first_name, last_name ].compact.join(" ")
  def full_label = [ display_name, (nickname ? "(#{nickname})" : nil) ].compact.join(" ")
  def years
    return nil unless birth_date || death_date
    "#{birth_date&.year || '?'}–#{death_date&.year}"
  end

  def parents  = Person.where(id: parent_links.select(:from_person_id)).by_name
  def children = Person.where(id: child_links.select(:to_person_id)).order(:birth_date, :first_name)
  def partners = Person.where(id: partner_out.select(:to_person_id)).or(Person.where(id: partner_in.select(:from_person_id))).by_name
  def siblings = Person.where(id: Relationship.parents.where(from_person_id: parents.select(:id)).select(:to_person_id)).where.not(id: id).by_name

  # Details a child's family may prefer to keep from the wider family.
  # membership: the viewer's membership in this person's family.
  def details_visible_to?(membership)
    !hide_details? || membership.organizer? || membership.person_id == id
  end

  private

  def household_is_in_this_family
    errors.add(:household, "belongs to a different family") if household && household.family_id != family_id
  end

  def dates_in_order
    errors.add(:death_date, "is before the birth date") if birth_date && death_date && death_date < birth_date
  end
end
