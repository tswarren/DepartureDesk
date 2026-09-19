# frozen_string_literal: true

class HardenM3e3DepositAttestationBindings < ActiveRecord::Migration[8.1]
  def up
    add_column :supplier_commitment_dispositions, :supplier_deposit_requirement_tranche_id, :uuid

    add_index :supplier_commitments,
      [
        :id, :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      unique: true,
      name: "index_supplier_commitments_on_deposit_opening_owner"

    add_index :supplier_deposit_external_attestations,
      [
        :id, :supplier_commitment_id, :supplier_deposit_requirement_tranche_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      unique: true,
      name: "index_deposit_attestations_on_opening_owner"

    # Attestation must name the same commitment+tranche opening pair.
    add_foreign_key :supplier_deposit_external_attestations, :supplier_commitments,
      column: [
        :supplier_commitment_id, :supplier_deposit_requirement_tranche_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_attestations_opening_fk"

    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_deposit_attestation_fk"

    # Disposition proof must bind attestation + commitment + tranche together.
    add_foreign_key :supplier_commitment_dispositions, :supplier_deposit_external_attestations,
      column: [
        :supplier_deposit_external_attestation_id, :supplier_commitment_id,
        :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_commitment_id, :supplier_deposit_requirement_tranche_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_deposit_attestation_fk"

    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome_proof"
    add_check_constraint :supplier_commitment_dispositions,
      "(" \
        "outcome IN ('satisfied', 'released') AND supplier_commitment_evidence_coverage_id IS NOT NULL " \
        "AND reason IS NULL AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NULL AND supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "outcome = 'waived' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND reason IS NOT NULL AND btrim(reason) <> '' AND accepted_risk_acknowledged = TRUE " \
        "AND replacement_supplier_commitment_id IS NULL AND supplier_deposit_external_attestation_id IS NULL " \
        "AND supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "outcome = 'cancelled' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NULL AND supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "outcome = 'superseded' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NOT NULL " \
        "AND replacement_supplier_commitment_id <> supplier_commitment_id " \
        "AND supplier_deposit_external_attestation_id IS NULL AND supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "outcome = 'handled_externally' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND reason IS NOT NULL AND btrim(reason) <> '' AND accepted_risk_acknowledged = FALSE " \
        "AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NOT NULL " \
        "AND supplier_deposit_requirement_tranche_id IS NOT NULL" \
      ")",
      name: "commitment_dispositions_outcome_proof"
  end

  def down
    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome_proof"
    add_check_constraint :supplier_commitment_dispositions,
      "(" \
        "outcome IN ('satisfied', 'released') AND supplier_commitment_evidence_coverage_id IS NOT NULL " \
        "AND reason IS NULL AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NULL" \
      ") OR (" \
        "outcome = 'waived' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND reason IS NOT NULL AND btrim(reason) <> '' AND accepted_risk_acknowledged = TRUE " \
        "AND replacement_supplier_commitment_id IS NULL AND supplier_deposit_external_attestation_id IS NULL" \
      ") OR (" \
        "outcome = 'cancelled' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NULL" \
      ") OR (" \
        "outcome = 'superseded' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NOT NULL " \
        "AND replacement_supplier_commitment_id <> supplier_commitment_id " \
        "AND supplier_deposit_external_attestation_id IS NULL" \
      ") OR (" \
        "outcome = 'handled_externally' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND reason IS NOT NULL AND btrim(reason) <> '' AND accepted_risk_acknowledged = FALSE " \
        "AND replacement_supplier_commitment_id IS NULL " \
        "AND supplier_deposit_external_attestation_id IS NOT NULL" \
      ")",
      name: "commitment_dispositions_outcome_proof"

    remove_foreign_key :supplier_commitment_dispositions, name: "commitment_dispositions_deposit_attestation_fk"
    add_foreign_key :supplier_commitment_dispositions, :supplier_deposit_external_attestations,
      column: [
        :supplier_deposit_external_attestation_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_deposit_attestation_fk"

    remove_foreign_key :supplier_deposit_external_attestations, name: "deposit_attestations_opening_fk"
    remove_index :supplier_deposit_external_attestations, name: "index_deposit_attestations_on_opening_owner"
    remove_index :supplier_commitments, name: "index_supplier_commitments_on_deposit_opening_owner"
    remove_column :supplier_commitment_dispositions, :supplier_deposit_requirement_tranche_id
  end
end
