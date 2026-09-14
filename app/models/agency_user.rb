class AgencyUser < ApplicationRecord
  STATUSES = %w[invited active suspended closed].freeze
  ACCESS_ROLES = %w[administrator staff viewer].freeze
  INVITATION_TTL = 7.days
  PASSWORD_RESET_TTL = 15.minutes

  has_secure_password validations: false

  belongs_to :agency
  belongs_to :default_office, class_name: "Office", optional: true
  has_many :sessions, dependent: :destroy

  enum :status, STATUSES.index_by(&:itself), validate: true
  enum :access_role, ACCESS_ROLES.index_by(&:itself), validate: true, prefix: :role

  attr_readonly :agency_id

  normalizes :email_address, with: ->(value) { normalize_email(value) }
  normalizes :first_name, :last_name, :title, :phone, with: ->(value) { value.to_s.strip.presence }
  normalizes :preferred_name, :relationship, with: ->(value) { value.to_s.strip.presence }

  validates :email_address, :first_name, :last_name, presence: true
  validates :email_address, uniqueness: { scope: :agency_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10, maximum: 72 }, confirmation: true, if: -> { password.present? }
  validate :default_office_belongs_to_agency
  validate :active_password_present

  def self.normalize_email(value)
    value.to_s.strip.downcase
  end

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def display_name
    preferred_name.presence || "#{first_name} #{last_name}".squish
  end

  def permitted?(permission)
    active? && AccessPermission.allowed?(access_role, permission)
  end

  def issue_invitation_token
    raw = SecureRandom.urlsafe_base64(32)
    self.invitation_token_digest = self.class.digest_token(raw)
    self.invitation_sent_at = Time.current
    self.invitation_expires_at = INVITATION_TTL.from_now
    raw
  end

  def invitation_current?(raw_token)
    invited? &&
      invitation_token_digest.present? &&
      invitation_expires_at&.future? &&
      ActiveSupport::SecurityUtils.secure_compare(invitation_token_digest, self.class.digest_token(raw_token))
  end

  def issue_password_reset_token
    raw = SecureRandom.urlsafe_base64(32)
    self.password_reset_token_digest = self.class.digest_token(raw)
    self.password_reset_sent_at = Time.current
    self.password_reset_expires_at = PASSWORD_RESET_TTL.from_now
    raw
  end

  def password_reset_current?(raw_token)
    active? &&
      password_reset_token_digest.present? &&
      password_reset_expires_at&.future? &&
      ActiveSupport::SecurityUtils.secure_compare(password_reset_token_digest, self.class.digest_token(raw_token))
  end

  def clear_invitation!
    self.invitation_token_digest = nil
    self.invitation_sent_at = nil
    self.invitation_expires_at = nil
  end

  def clear_password_reset!
    self.password_reset_token_digest = nil
    self.password_reset_sent_at = nil
    self.password_reset_expires_at = nil
  end

  private

  def default_office_belongs_to_agency
    return if default_office.blank?
    return if default_office.agency_id == agency_id

    errors.add(:default_office, "must belong to the same agency")
  end

  def active_password_present
    return unless active?
    return if password_digest.present? || password.present?

    errors.add(:password, "is required")
  end
end
