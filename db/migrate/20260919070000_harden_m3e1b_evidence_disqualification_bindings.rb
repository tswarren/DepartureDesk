# frozen_string_literal: true

class HardenM3e1bEvidenceDisqualificationBindings < ActiveRecord::Migration[8.1]
  def up
    add_binding_indexes!
    replace_disqualification_foreign_keys!
  end

  def down
    remove_foreign_key :supplier_commitment_evidence_member_disqualifications,
      name: "commitment_evidence_disqualifications_reopening_fk"
    remove_foreign_key :supplier_commitment_evidence_member_disqualifications,
      name: "commitment_evidence_disqualifications_disposition_fk"

    add_foreign_key :supplier_commitment_evidence_member_disqualifications, :supplier_commitment_dispositions,
      column: [
        :supplier_commitment_disposition_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_evidence_disqualifications_disposition_fk"
    add_foreign_key :supplier_commitment_evidence_member_disqualifications, :supplier_commitment_reopenings,
      column: [ :supplier_commitment_reopening_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "commitment_evidence_disqualifications_reopening_fk"

    remove_index :supplier_commitment_reopenings,
      name: "index_commitment_reopenings_on_disposition_commitment_owner"
    remove_index :supplier_commitment_dispositions,
      name: "index_commitment_dispositions_on_coverage_member_owner"
  end

  private

  def add_binding_indexes!
    add_index :supplier_commitment_dispositions,
      [
        :id, :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      unique: true,
      name: "index_commitment_dispositions_on_coverage_member_owner"

    add_index :supplier_commitment_reopenings,
      [
        :id, :supplier_commitment_disposition_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      unique: true,
      name: "index_commitment_reopenings_on_disposition_commitment_owner"
  end

  def replace_disqualification_foreign_keys!
    remove_foreign_key :supplier_commitment_evidence_member_disqualifications,
      name: "commitment_evidence_disqualifications_reopening_fk"
    remove_foreign_key :supplier_commitment_evidence_member_disqualifications,
      name: "commitment_evidence_disqualifications_disposition_fk"

    add_foreign_key :supplier_commitment_evidence_member_disqualifications, :supplier_commitment_dispositions,
      column: [
        :supplier_commitment_disposition_id, :supplier_commitment_evidence_coverage_id,
        :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_evidence_disqualifications_disposition_fk"

    add_foreign_key :supplier_commitment_evidence_member_disqualifications, :supplier_commitment_reopenings,
      column: [
        :supplier_commitment_reopening_id, :supplier_commitment_disposition_id,
        :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_commitment_disposition_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_evidence_disqualifications_reopening_fk"
  end
end
