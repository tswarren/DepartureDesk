# frozen_string_literal: true

class ServiceOfferVersion < ApplicationRecord
  STATUSES = %w[draft abandoned published superseded retired].freeze
  ABANDONED_REASON_LIMIT = 500
  ALLOWED_LIFECYCLE_TRANSITIONS = {
    "draft" => %w[abandoned]
  }.freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer

  has_one :definition, class_name: "ServiceOfferDefinition", dependent: :restrict_with_exception
  has_one :price_definition, class_name: "ServiceOfferPriceDefinition", dependent: :restrict_with_exception
  has_many :source_bindings, class_name: "ServiceOfferSourceBinding", dependent: :restrict_with_exception
  has_many :price_components, class_name: "ServiceOfferPriceComponent", dependent: :restrict_with_exception
  has_many :price_component_bases, class_name: "ServiceOfferPriceComponentBase", dependent: :restrict_with_exception
  belongs_to :owning_package_version, class_name: "PackageVersion", optional: true
  has_many :package_inclusions, dependent: :restrict_with_exception
  has_many :choice_groups, class_name: "ServiceOfferChoiceGroup", dependent: :restrict_with_exception
  has_many :choice_options, class_name: "ServiceOfferChoiceOption", dependent: :restrict_with_exception
  has_one :payment_schedule, class_name: "ServiceOfferClientPaymentSchedule", dependent: :restrict_with_exception
  has_one :cancellation_policy, class_name: "ServiceOfferClientCancellationPolicy", dependent: :restrict_with_exception
  has_many :stated_conditions, class_name: "ServiceOfferClientStatedCondition", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft"

  attr_readonly :agency_id, :departure_id, :service_offer_id, :version_number

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
