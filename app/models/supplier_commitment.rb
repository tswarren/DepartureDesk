class SupplierCommitment < ApplicationRecord
  include AppendOnlyRecord

  COMMITMENT_TYPES = %w[quantity monetary quantity_and_monetary].freeze
  QUANTITY_BASES = SupplierCommitmentTriggerDefinition::QUANTITY_BASES

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_arrangement_activation, optional: true
  belongs_to :supplier_commitment_trigger_definition
  belongs_to :supplier_confirmation
  belongs_to :committed_supplier, class_name: "Supplier"
  belongs_to :arrangement_item, optional: true
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :capacity_pool, optional: true
  belongs_to :supplier_cost_source, optional: true
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  enum :commitment_type, COMMITMENT_TYPES.index_by(&:itself), validate: true
  enum :quantity_basis, QUANTITY_BASES.index_by(&:itself), validate: { allow_nil: true }

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  monetize :amount_minor_units, as: :amount, with_model_currency: :currency, allow_nil: true

  validates :description, :calculation_snapshot, :opened_at, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :amount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
