# frozen_string_literal: true

# Staff attestation that a deposit tranche was handled outside DepartureDesk.
# Never labeled paid. Paired with disposition outcome handled_externally.
class SupplierDepositExternalAttestation < ApplicationRecord
  include AppendOnlyRecord

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_tranche
  belongs_to :supplier_commitment
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  has_one :supplier_commitment_disposition, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  monetize :attested_amount_minor_units, as: :attested_amount, with_model_currency: :currency

  validates :note, :currency, :occurred_at, :recorded_at, presence: true
  validates :confirmed_complete, inclusion: { in: [ true ] }
  validates :note, length: { maximum: 2000 }
  validates :attested_amount_minor_units, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
