class PartyContactPoint < ApplicationRecord
  KINDS = %w[
    postal_address
    phone
    email
  ].freeze

  STATUSES = %w[
    active
    deactivated
  ].freeze

  belongs_to :agency
  belongs_to :party, inverse_of: :contact_points
  belongs_to :deactivated_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false
  belongs_to :suppressed_by_membership,
    class_name: "AgencyMembership",
    optional: true,
    inverse_of: false

  has_one :postal_address,
    class_name: "PartyPostalAddress",
    foreign_key: :contact_point_id,
    inverse_of: :contact_point,
    dependent: :restrict_with_exception
  has_one :phone_number,
    class_name: "PartyPhoneNumber",
    foreign_key: :contact_point_id,
    inverse_of: :contact_point,
    dependent: :restrict_with_exception
  has_one :email_address,
    class_name: "PartyEmailAddress",
    foreign_key: :contact_point_id,
    inverse_of: :contact_point,
    dependent: :restrict_with_exception
  has_many :purpose_assignments,
    class_name: "ContactPointPurposeAssignment",
    inverse_of: :contact_point,
    dependent: :restrict_with_exception

  enum :contact_kind, KINDS.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :party_id, :contact_kind

  normalizes :label, with: ->(value) { value&.strip.presence }
  normalizes :deactivation_reason, :suppression_reason, with: ->(value) { value&.strip.presence }

  validates :normalized_value, presence: true
  validates :normalized_value, uniqueness: {
    scope: [ :party_id, :contact_kind ],
    conditions: -> { where(status: "active") },
    if: :active?,
    message: "is already recorded for this party"
  }
  validate :deactivation_matches_status
  validate :suppression_complete
  validate :actors_same_agency

  scope :current, -> { active }
  scope :history, -> { deactivated }

  def suppressed?
    suppressed_at.present?
  end

  def eligible_destination?
    active? && !suppressed?
  end

  def detail
    case contact_kind
    when "postal_address" then postal_address
    when "phone" then phone_number
    when "email" then email_address
    end
  end

  def display_value
    case contact_kind
    when "postal_address" then postal_address&.formatted_address
    when "phone" then phone_number&.display_number
    when "email" then email_address&.display_address
    end
  end

  def kind_label
    contact_kind.titleize
  end

  private

  def deactivation_matches_status
    if active?
      errors.add(:deactivated_at, "must be blank") if deactivated_at.present?
      errors.add(:deactivated_by_membership_id, "must be blank") if deactivated_by_membership_id.present?
      errors.add(:deactivation_reason, "must be blank") if deactivation_reason.present?
    elsif deactivated?
      errors.add(:deactivated_at, "must be present") if deactivated_at.blank?
      errors.add(:deactivated_by_membership_id, "must be present") if deactivated_by_membership_id.blank?
      errors.add(:deactivation_reason, "must be present") if deactivation_reason.blank?
    end
  end

  def suppression_complete
    complete = suppressed_at.present? && suppressed_by_membership_id.present? && suppression_reason.present?
    empty = suppressed_at.blank? && suppressed_by_membership_id.blank? && suppression_reason.blank?
    return if complete || empty

    errors.add(:suppression_reason, "must be complete or blank")
  end

  def actors_same_agency
    if deactivated_by_membership.present? && agency_id.present? && deactivated_by_membership.agency_id != agency_id
      errors.add(:deactivated_by_membership, "must belong to the same agency")
    end
    if suppressed_by_membership.present? && agency_id.present? && suppressed_by_membership.agency_id != agency_id
      errors.add(:suppressed_by_membership, "must belong to the same agency")
    end
  end
end
