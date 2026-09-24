# frozen_string_literal: true

class ServiceOfferPriceComponent < ApplicationRecord
  include DraftVersionDefinition
  guards_draft_version :service_offer_version

  CLIENT_ROLES = %w[base_price named_discount named_surcharge tax_fee].freeze
  CALCULATION_KINDS = %w[fixed unit_rate percentage].freeze
  QUANTITY_BASES = %w[
    service_instances persons resource_units nights person_nights resource_nights
    occupancy_positions occupancy_position_nights
  ].freeze
  UNIT_RATE_BASES = QUANTITY_BASES - %w[service_instances]
  PERCENTAGE_TREATMENTS = %w[additive included].freeze
  LABEL_LIMIT = 160
  RATE_CATEGORY_LIMIT = 80
  OCCUPANCY_POSITION_LIMIT = 40

  belongs_to :agency
  belongs_to :departure
  belongs_to :service_offer
  belongs_to :service_offer_version
  belongs_to :service_offer_price_definition
  belongs_to :copied_from_supplier_cost_component, class_name: "SupplierCostComponent", optional: true

  has_many :service_offer_price_component_bases, class_name: "ServiceOfferPriceComponentBase",
    dependent: :restrict_with_exception
  has_many :dependent_base_links, class_name: "ServiceOfferPriceComponentBase",
    foreign_key: :base_component_id, inverse_of: :base_component,
    dependent: :restrict_with_exception

  enum :client_role, CLIENT_ROLES.index_by(&:itself), validate: true
  enum :calculation_kind, CALCULATION_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }
  enum :percentage_treatment, PERCENTAGE_TREATMENTS.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :service_offer_id,
    :service_offer_version_id, :service_offer_price_definition_id

  normalizes :label, with: ->(value) { value.to_s.strip }
  normalizes :client_rate_category_key, :occupancy_position_key, :cruise_client_term_row_key,
    with: ->(value) { value.to_s.strip.presence }

  monetize :amount_minor_units, as: :amount, with_model_currency: :currency, allow_nil: true

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :client_rate_category_key, length: { maximum: RATE_CATEGORY_LIMIT }, allow_nil: true
  validates :occupancy_position_key, length: { maximum: OCCUPANCY_POSITION_LIMIT }, allow_nil: true
  validates :cruise_client_term_row_key, length: { maximum: 80 }, allow_nil: true
  validate :provenance_is_complete
  validate :provenance_mapping_shape
  validate :kind_shape
  validate :included_treatment_is_tax_fee
  validate :parent_is_calculated

  def currency
    service_offer_price_definition&.currency
  end

  def included_tax_allocation?
    tax_fee? && included?
  end

  def signed_revenue_direction
    return 0 if included_tax_allocation?
    return -1 if named_discount?

    1
  end

  def matches_selectors?(rate_category:, occupancy_position:)
    selector_matches?(client_rate_category_key, rate_category) &&
      selector_matches?(occupancy_position_key, occupancy_position)
  end

  private

  def selector_matches?(selector, value)
    selector.blank? || selector == value.to_s.presence
  end

  def kind_shape
    case calculation_kind
    when "fixed"
      errors.add(:amount_minor_units, "can't be blank") if amount_minor_units.nil?
      errors.add(:quantity_basis, "must be service instances") unless quantity_basis == "service_instances"
      errors.add(:rate, "must be blank") if rate.present?
      errors.add(:percentage_treatment, "must be blank") if percentage_treatment.present?
    when "unit_rate"
      errors.add(:amount_minor_units, "can't be blank") if amount_minor_units.nil?
      errors.add(:quantity_basis, "can't be blank") if quantity_basis.blank?
      unless quantity_basis.blank? || UNIT_RATE_BASES.include?(quantity_basis)
        errors.add(:quantity_basis, "is not a unit-rate basis")
      end
      errors.add(:rate, "must be blank") if rate.present?
      errors.add(:percentage_treatment, "must be blank") if percentage_treatment.present?
    when "percentage"
      errors.add(:rate, "can't be blank") if rate.nil?
      errors.add(:percentage_treatment, "can't be blank") if percentage_treatment.blank?
      errors.add(:amount_minor_units, "must be blank") if amount_minor_units.present?
      errors.add(:quantity_basis, "must be blank") if quantity_basis.present?
    end
  end

  def included_treatment_is_tax_fee
    return unless percentage_treatment == "included"
    return if tax_fee?

    errors.add(:percentage_treatment, "included treatment is only valid for a tax or fee")
  end

  def provenance_is_complete
    fields = [
      copied_from_supplier_cost_component_id,
      copied_from_supplier_cost_component_fingerprint,
      copied_from_supplier_cost_component_at,
      copied_from_supplier_cost_component_mapping
    ]
    return if fields.all?(&:nil?) || fields.all?(&:present?)

    errors.add(:base, "Supplier copy provenance must be complete")
  end

  def provenance_mapping_shape
    mapping = copied_from_supplier_cost_component_mapping
    return if mapping.nil?
    return if SupplierCostComponentCopyFingerprint.valid_snapshot?(mapping)

    errors.add(:copied_from_supplier_cost_component_mapping, "is not a supported copy mapping")
  end

  def parent_is_calculated
    return if service_offer_price_definition.nil? || service_offer_price_definition.calculated?

    errors.add(:base, "Zero-price definitions cannot contain components")
  end
end
