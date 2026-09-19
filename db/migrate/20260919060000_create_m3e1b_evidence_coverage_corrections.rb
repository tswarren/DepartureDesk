# frozen_string_literal: true

class CreateM3e1bEvidenceCoverageCorrections < ActiveRecord::Migration[8.1]
  def up
    create_revocations!
    create_disqualifications!
    create_immutability_triggers!
  end

  def down
    drop_table :supplier_commitment_evidence_member_disqualifications, if_exists: true
    drop_table :supplier_commitment_evidence_coverage_revocations, if_exists: true
  end

  private

  def create_revocations!
    create_table :supplier_commitment_evidence_coverage_revocations, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_commitment_evidence_coverage_id, null: false
      table.string :reason, null: false, limit: 2_000
      table.uuid :actor_id, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_evidence_coverage_revocations, "cmt_ev_rev")
    add_index :supplier_commitment_evidence_coverage_revocations,
      :supplier_commitment_evidence_coverage_id,
      unique: true,
      name: "index_commitment_evidence_revocations_on_coverage"
    add_index :supplier_commitment_evidence_coverage_revocations,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_commitment_evidence_revocations_on_version_owner"
    add_version_fk(:supplier_commitment_evidence_coverage_revocations, "commitment_evidence_revocations_version_fk")
    add_foreign_key :supplier_commitment_evidence_coverage_revocations, :supplier_commitment_evidence_coverages,
      column: [
        :supplier_commitment_evidence_coverage_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_evidence_revocations_coverage_fk"
    add_actor_fk(:supplier_commitment_evidence_coverage_revocations, "commitment_evidence_revocations_actor_fk")
    add_idempotency_fk(:supplier_commitment_evidence_coverage_revocations, "commitment_evidence_revocations_idempotency_fk")
    add_check_constraint :supplier_commitment_evidence_coverage_revocations,
      "btrim(reason) <> '' AND char_length(reason) <= 2000",
      name: "commitment_evidence_revocations_reason"
  end

  def create_disqualifications!
    create_table :supplier_commitment_evidence_member_disqualifications, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_commitment_evidence_coverage_id, null: false
      table.uuid :supplier_commitment_id, null: false
      table.uuid :supplier_commitment_disposition_id, null: false
      table.uuid :supplier_commitment_reopening_id, null: false
      table.string :reason, null: false, limit: 2_000
      table.uuid :actor_id, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_evidence_member_disqualifications, "cmt_ev_disq")
    add_index :supplier_commitment_evidence_member_disqualifications,
      [ :supplier_commitment_evidence_coverage_id, :supplier_commitment_id ],
      unique: true,
      name: "index_commitment_evidence_disqualifications_on_coverage_member"
    add_index :supplier_commitment_evidence_member_disqualifications,
      :supplier_commitment_disposition_id,
      unique: true,
      name: "index_commitment_evidence_disqualifications_on_disposition"
    add_index :supplier_commitment_evidence_member_disqualifications,
      :supplier_commitment_reopening_id,
      unique: true,
      name: "index_commitment_evidence_disqualifications_on_reopening"
    add_index :supplier_commitment_evidence_member_disqualifications,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_commitment_evidence_disqualifications_on_version_owner"
    add_version_fk(:supplier_commitment_evidence_member_disqualifications, "commitment_evidence_disqualifications_version_fk")
    add_foreign_key :supplier_commitment_evidence_member_disqualifications, :supplier_commitment_evidence_coverage_members,
      column: [
        :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :supplier_commitment_evidence_coverage_id, :supplier_commitment_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_evidence_disqualifications_membership_fk"
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
    add_actor_fk(:supplier_commitment_evidence_member_disqualifications, "commitment_evidence_disqualifications_actor_fk")
    add_idempotency_fk(:supplier_commitment_evidence_member_disqualifications, "commitment_evidence_disqualifications_idempotency_fk")
    add_check_constraint :supplier_commitment_evidence_member_disqualifications,
      "btrim(reason) <> '' AND char_length(reason) <= 2000",
      name: "commitment_evidence_disqualifications_reason"
  end

  def create_immutability_triggers!
    %w[
      supplier_commitment_evidence_coverage_revocations
      supplier_commitment_evidence_member_disqualifications
    ].each do |table|
      execute <<~SQL.squish
        CREATE TRIGGER #{table}_reject_update
        BEFORE UPDATE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      SQL
      execute <<~SQL.squish
        CREATE TRIGGER #{table}_reject_delete
        BEFORE DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      SQL
    end
  end

  def owner_columns(table)
    table.uuid :agency_id, null: false
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
  end

  def identity_indexes(table, prefix)
    add_index table, [ :id, :agency_id ], unique: true, name: "index_#{prefix}_on_id_agency"
    add_index table, [ :id, :departure_id, :agency_id ], unique: true,
      name: "index_#{prefix}_on_id_departure_agency"
  end

  def add_version_fk(table, name)
    add_foreign_key table, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: name
  end

  def add_actor_fk(table, name)
    add_foreign_key table, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: name
  end

  def add_idempotency_fk(table, name)
    add_foreign_key table, :agency_command_idempotency_keys,
      column: [ :agency_command_idempotency_key_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: name
  end
end
