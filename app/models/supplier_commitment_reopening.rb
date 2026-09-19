# frozen_string_literal: true

class SupplierCommitmentReopening < ApplicationRecord
  include AppendOnlyRecord

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_commitment
  belongs_to :supplier_commitment_disposition
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :reason, :occurred_at, :recorded_at, presence: true
  validates :reason, length: { maximum: 2_000 }
end
