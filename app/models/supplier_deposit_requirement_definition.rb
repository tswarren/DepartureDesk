# frozen_string_literal: true

class SupplierDepositRequirementDefinition < ApplicationRecord
  include DraftVersionDefinition

  AMOUNT_SHAPES = %w[
    fixed_amount quantity_times_rate percentage_of_cost_sources cumulative_target
  ].freeze
  QUANTITY_BASES = %w[resource_units traveler_positions explicit].freeze
  ROUNDING_SCOPES = %w[aggregate per_source].freeze
  RULE_SHAPES = SupplierDeadlineDefinition::RULE_SHAPES
  PRECISIONS = SupplierDeadlineDefinition::PRECISIONS
  DESCRIPTION_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :copied_from, class_name: "SupplierDepositRequirementDefinition", optional: true

  has_many :supplier_deposit_requirement_definition_coverage_links, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_definition_cost_links, dependent: :restrict_with_exception
  has_many :supplier_deposit_requirement_tranches, dependent: :restrict_with_exception
  has_many :supplier_deadline_occurrences, dependent: :restrict_with_exception

  enum :amount_shape, AMOUNT_SHAPES.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }
  enum :rounding_scope, ROUNDING_SCOPES.index_by(&:itself), validate: { allow_nil: true }
  enum :rule_shape, RULE_SHAPES.index_by(&:itself), validate: true
  enum :precision, PRECISIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :copied_from_id

  monetize :fixed_amount_minor_units, as: :fixed_amount, with_model_currency: :currency, allow_nil: true
  monetize :rate_minor_units, as: :rate, with_model_currency: :currency, allow_nil: true
  monetize :target_amount_minor_units, as: :target_amount, with_model_currency: :currency, allow_nil: true

  normalizes :description, with: ->(value) { value.to_s.strip.presence }
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }
  normalizes :time_zone, with: ->(value) { value.to_s.strip }

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, :time_zone, presence: true
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_nil: true
  validate :timezone_is_iana

  def date_only?
    precision == "date_only"
  end

  def local_date_time?
    precision == "local_date_time"
  end

  private

  def timezone_is_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "is not a recognized IANA timezone")
  end
end
