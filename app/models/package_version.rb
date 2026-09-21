# frozen_string_literal: true

class PackageVersion < ApplicationRecord
  STATUSES = %w[draft abandoned published superseded retired].freeze
  ABANDONED_REASON_LIMIT = 500
  ALLOWED_LIFECYCLE_TRANSITIONS = {
    "draft" => %w[abandoned]
  }.freeze
  SALES_CAP_BASES = %w[package_bookings persons resource_units].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :package

  has_many :inclusions, class_name: "PackageInclusion", dependent: :restrict_with_exception
  has_many :owned_service_offer_versions, class_name: "ServiceOfferVersion",
    foreign_key: :owning_package_version_id, inverse_of: :owning_package_version,
    dependent: :restrict_with_exception
  has_one :price_definition, class_name: "PackagePriceDefinition", dependent: :restrict_with_exception
  has_one :payment_schedule, class_name: "PackageClientPaymentSchedule", dependent: :restrict_with_exception
  has_one :cancellation_policy, class_name: "PackageClientCancellationPolicy", dependent: :restrict_with_exception
  has_many :stated_conditions, class_name: "PackageClientStatedCondition", dependent: :restrict_with_exception
  has_many :term_resolutions, class_name: "PackageClientTermResolution", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id, :departure_id, :package_id, :version_number

  normalizes :abandoned_reason, with: ->(value) { value.to_s.strip.presence }

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }
  validates :abandoned_reason, length: { maximum: ABANDONED_REASON_LIMIT }, allow_nil: true
  validate :abandonment_fields_match_status
  validate :lifecycle_transition_is_permitted, on: :update

  private

  def abandonment_fields_match_status
    if abandoned?
      errors.add(:abandoned_at, "can't be blank") if abandoned_at.blank?
      errors.add(:abandoned_reason, "can't be blank") if abandoned_reason.blank?
    else
      errors.add(:abandoned_at, "must be blank unless abandoned") if abandoned_at.present?
      errors.add(:abandoned_reason, "must be blank unless abandoned") if abandoned_reason.present?
    end
  end

  def lifecycle_transition_is_permitted
    return unless status_changed?

    from = status_was
    to = status
    allowed = ALLOWED_LIFECYCLE_TRANSITIONS.fetch(from, [])
    return if allowed.include?(to)

    errors.add(:status, "transition from #{from} to #{to} is not permitted")
  end
end
