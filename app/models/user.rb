# Accounts are issued by an administrator (Admin > People and accounts); there is no sign-up.
class User < ApplicationRecord
  # name = the display name the family sees (the person chooses it).
  validates :name, length: { maximum: 60 }
  before_validation { self.name = name.to_s.squish.presence }

  belongs_to :person, optional: true
  has_many :board_posts, dependent: :destroy
  has_many :date_votes, dependent: :destroy
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :lockable, :trackable, :timeoutable

  PASSWORD_RULE = "8 or more characters, with a lowercase letter, an uppercase letter, a number and a symbol".freeze
  validate :password_has_mix, if: -> { password.present? }

  def password_has_mix
    ok = password =~ /[[:lower:]]/ && password =~ /[[:upper:]]/ && password =~ /\d/ && password =~ /[^[:alnum:]]/
    errors.add(:base, "Password needs #{PASSWORD_RULE}.") unless ok
  end

  def label = name.presence || person&.display_name || "A family member"

  # A one-time link the person opens to set their own password. No email is sent; the administrator hands the
  # link over. Hashed with plain SHA-256 so a link issued from any machine validates on the server.
  def self.set_password_digest(raw) = Digest::SHA256.hexdigest(raw.to_s)

  def issue_set_password_token!
    raw = SecureRandom.urlsafe_base64(32)
    update_columns(reset_password_token: User.set_password_digest(raw), reset_password_sent_at: Time.current)
    raw
  end
end
