# frozen_string_literal: true

class SupplierDepositRequirementTranche < ApplicationRecord
  AMOUNT_SHAPES = SupplierDepositRequirementDefinition::AMOUNT_SHAPES

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_definition
  belongs_to :supplier_arrangement_activation, optional: true
  belongs_to :predecessor_tranche, class_name: "SupplierDepositRequirementTranche", optional: true
  belongs_to :governing_deadline_occurrence, class_name: "SupplierDeadlineOccurrence", optional: true
  belongs_to :actor, class_name: "AgencyUser"

  has_many :supplier_deposit_requirement_tranche_components, dependent: :restrict_with_exception
  has_one :supplier_commitment, dependent: :restrict_with_exception
  has_many :supplier_deposit_external_attestations, dependent: :restrict_with_exception

  enum :amount_shape, AMOUNT_SHAPES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  monetize :initial_amount_minor_units, as: :initial_amount, with_model_currency: :currency
  monetize :current_amount_minor_units, as: :current_amount, with_model_currency: :currency

  validates :materialization_key, :currency, :materialized_at, presence: true
  validates :initial_amount_minor_units, :current_amount_minor_units,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def open_commitment
    commitment = supplier_commitment
    return unless commitment
    return unless commitment.open_state?

    commitment
  end

  def apply_current_amount!(amount_minor_units:)
    update!(current_amount_minor_units: amount_minor_units)
  end

  def replace_governing_deadline!(occurrence:)
    update!(governing_deadline_occurrence: occurrence)
  end
end
