# A workspace: one family's tree, households, reunions and forum. Nothing crosses between families.
class Family < ApplicationRecord
  RESERVED = %w[f new admin platform invite account users up assets].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :households, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :announcements, dependent: :destroy
  has_many :surveys, dependent: :destroy
  has_many :survey_opt_outs, dependent: :destroy
  has_many :relationships, dependent: :destroy
  has_many :reunions, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :email_deliveries, dependent: :destroy
  has_many :board_posts, dependent: :destroy

  KINDS = %w[family group].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, length: { maximum: 40 }, format: { with: /\A[a-z0-9]+(-[a-z0-9]+)*\z/ },
                   uniqueness: true, exclusion: { in: RESERVED }
  before_validation do
    self.name = name.to_s.squish
    self.slug = slug.to_s.strip.downcase.presence || name.to_s.parameterize
  end

  def terms = Terms.for(kind)
  def to_param = slug
end
