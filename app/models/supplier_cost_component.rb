class SupplierCostComponent < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  ECONOMIC_ROLES = %w[supplier_charge supplier_credit expected_commission informational_allocation].freeze
  CALCULATION_KINDS = %w[fixed unit_rate percentage minimum_amount_shortfall minimum_quantity_shortfall].freeze
  QUANTITY_BASES = %w[
    resource_units persons nights resource_nights person_nights occupancy_positions
    occupancy_position_nights single_occupancy_units single_occupancy_nights
  ].freeze
  PERCENTAGE_TREATMENTS = %w[additive included].freeze
  LABEL_LIMIT = 160

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_cost_definition
  belongs_to :participant_category, class_name: "SupplierCostParticipantCategory", optional: true

  has_many :supplier_cost_component_bases, class_name: "SupplierCostComponentBase",
    dependent: :restrict_with_exception
  has_many :dependent_base_links, class_name: "SupplierCostComponentBase",
    foreign_key: :base_component_id, inverse_of: :base_component,
    dependent: :restrict_with_exception

  enum :economic_role, ECONOMIC_ROLES.index_by(&:itself), validate: true
  enum :calculation_kind, CALCULATION_KINDS.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }
  enum :percentage_treatment, PERCENTAGE_TREATMENTS.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_cost_definition_id

  normalizes :label, with: ->(value) { value.to_s.strip }

  monetize :amount_minor_units, as: :amount, with_model_currency: :currency, allow_nil: true
  monetize :minimum_minor_units, as: :minimum, with_model_currency: :currency, allow_nil: true

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :amount_minor_units, :minimum_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :minimum_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def currency
    supplier_cost_definition&.currency
  end
end
