# frozen_string_literal: true

class SupplierCommitmentEvidenceCoverageMember < ApplicationRecord
  include AppendOnlyRecord

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_commitment_evidence_coverage
  belongs_to :supplier_commitment

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id
end
