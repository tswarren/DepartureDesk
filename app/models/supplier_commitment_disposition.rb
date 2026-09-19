# frozen_string_literal: true

class SupplierCommitmentDisposition < ApplicationRecord
  include AppendOnlyRecord

  OUTCOMES = %w[satisfied released waived cancelled superseded handled_externally].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_commitment
  belongs_to :supplier_commitment_evidence_coverage, optional: true
  belongs_to :supplier_deposit_external_attestation, optional: true
  belongs_to :supplier_deposit_requirement_tranche, optional: true
  belongs_to :replacement_supplier_commitment, class_name: "SupplierCommitment", optional: true
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true
  has_one :supplier_commitment_reopening, dependent: :restrict_with_exception

  enum :outcome, OUTCOMES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :occurred_at, :recorded_at, presence: true

  def reopened?
    supplier_commitment_reopening.present?
  end

  def current?
    !reopened?
  end
end
