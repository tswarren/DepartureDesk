# frozen_string_literal: true

class SupplierCommitmentEvidenceCoverage < ApplicationRecord
  include AppendOnlyRecord

  PURPOSES = %w[satisfied released].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_confirmation
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  has_many :members,
    class_name: "SupplierCommitmentEvidenceCoverageMember",
    dependent: :restrict_with_exception,
    inverse_of: :supplier_commitment_evidence_coverage
  has_many :supplier_commitments, through: :members
  has_many :supplier_commitment_dispositions, dependent: :restrict_with_exception
  has_one :supplier_commitment_evidence_coverage_revocation, dependent: :restrict_with_exception
  has_many :supplier_commitment_evidence_member_disqualifications, dependent: :restrict_with_exception

  enum :purpose, PURPOSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :recorded_at, presence: true

  def revoked?
    supplier_commitment_evidence_coverage_revocation.present?
  end

  def current_dependent_commitments
    supplier_commitment_dispositions.includes(:supplier_commitment_reopening, :supplier_commitment)
      .select(&:current?)
      .map(&:supplier_commitment)
      .uniq
  end
end
