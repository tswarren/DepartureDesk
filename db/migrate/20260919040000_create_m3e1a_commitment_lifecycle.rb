# frozen_string_literal: true

class CreateM3e1aCommitmentLifecycle < ActiveRecord::Migration[8.1]
  def up
    add_opening_kind!
    create_evidence_coverages!
    create_evidence_coverage_members!
    create_dispositions!
    create_reopenings!
    create_immutability_triggers!
  end

  def down
    drop_table :supplier_commitment_reopenings, if_exists: true
    drop_table :supplier_commitment_dispositions, if_exists: true
    drop_table :supplier_commitment_evidence_coverage_members, if_exists: true
    drop_table :supplier_commitment_evidence_coverages, if_exists: true
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_kind"
    remove_column :supplier_commitments, :opening_kind
  end

  private

  def add_opening_kind!
    add_column :supplier_commitments, :opening_kind, :string, null: false,
      default: "confirmation_trigger"
    add_check_constraint :supplier_commitments,
      "opening_kind = 'confirmation_trigger'",
      name: "supplier_commitments_opening_kind"
  end

  def create_evidence_coverages!
    create_table :supplier_commitment_evidence_coverages, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_confirmation_id, null: false
      table.string :purpose, null: false
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_evidence_coverages)
    add_index :supplier_commitment_evidence_coverages,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_evidence_coverages_on_version_owner"
    add_version_fk(:supplier_commitment_evidence_coverages, "commitment_evidence_coverages_version_fk")
    add_confirmation_fk(:supplier_commitment_evidence_coverages, "commitment_evidence_coverages_confirmation_fk")
    add_actor_fk(:supplier_commitment_evidence_coverages, "commitment_evidence_coverages_actor_fk")
    add_idempotency_fk(:supplier_commitment_evidence_coverages, "commitment_evidence_coverages_idempotency_fk")
    add_check_constraint :supplier_commitment_evidence_coverages,
      "purpose IN ('satisfied', 'released')",
      name: "commitment_evidence_coverages_purpose"
  end

  def create_evidence_coverage_members!
    create_table :supplier_commitment_evidence_coverage_members, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_commitment_evidence_coverage_id, null: false
      table.uuid :supplier_commitment_id, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_evidence_coverage_members)
    add_index :supplier_commitment_evidence_coverage_members,
      [ :supplier_commitment_evidence_coverage_id, :supplier_commitment_id ],
      unique: true, name: "index_commitment_evidence_members_on_coverage_commitment"
    add_index :supplier_commitment_evidence_coverage_members,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_evidence_members_on_version_owner"
    add_version_fk(:supplier_commitment_evidence_coverage_members, "commitment_evidence_members_version_fk")
    add_foreign_key :supplier_commitment_evidence_coverage_members, :supplier_commitment_evidence_coverages,
      column: [ :supplier_commitment_evidence_coverage_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_evidence_members_coverage_fk"
    add_foreign_key :supplier_commitment_evidence_coverage_members, :supplier_commitments,
      column: [ :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_evidence_members_commitment_fk"
  end

  def create_dispositions!
    create_table :supplier_commitment_dispositions, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_commitment_id, null: false
      table.string :outcome, null: false
      table.uuid :supplier_commitment_evidence_coverage_id
      table.uuid :replacement_supplier_commitment_id
      table.string :reason, limit: 2_000
      table.boolean :accepted_risk_acknowledged, null: false, default: false
      table.uuid :actor_id, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_dispositions)
    add_index :supplier_commitment_dispositions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_dispositions_on_version_owner"
    add_index :supplier_commitment_dispositions,
      [ :supplier_commitment_id, :recorded_at, :id ],
      name: "index_commitment_dispositions_on_commitment_timeline"
    add_version_fk(:supplier_commitment_dispositions, "commitment_dispositions_version_fk")
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitments,
      column: [ :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_dispositions_commitment_fk"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitment_evidence_coverages,
      column: [ :supplier_commitment_evidence_coverage_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_dispositions_coverage_fk"
    add_foreign_key :supplier_commitment_dispositions, :supplier_commitments,
      column: [ :replacement_supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_dispositions_replacement_fk"
    add_actor_fk(:supplier_commitment_dispositions, "commitment_dispositions_actor_fk")
    add_idempotency_fk(:supplier_commitment_dispositions, "commitment_dispositions_idempotency_fk")
    add_check_constraint :supplier_commitment_dispositions,
      "outcome IN ('satisfied', 'released', 'waived', 'cancelled', 'superseded')",
      name: "commitment_dispositions_outcome"
    add_check_constraint :supplier_commitment_dispositions,
      "(" \
        "outcome IN ('satisfied', 'released') AND supplier_commitment_evidence_coverage_id IS NOT NULL " \
        "AND reason IS NULL AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL" \
      ") OR (" \
        "outcome = 'waived' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND reason IS NOT NULL AND btrim(reason) <> '' AND accepted_risk_acknowledged = TRUE " \
        "AND replacement_supplier_commitment_id IS NULL" \
      ") OR (" \
        "outcome = 'cancelled' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NULL" \
      ") OR (" \
        "outcome = 'superseded' AND supplier_commitment_evidence_coverage_id IS NULL " \
        "AND accepted_risk_acknowledged = FALSE AND replacement_supplier_commitment_id IS NOT NULL " \
        "AND replacement_supplier_commitment_id <> supplier_commitment_id" \
      ")",
      name: "commitment_dispositions_outcome_proof"
    add_check_constraint :supplier_commitment_dispositions,
      "reason IS NULL OR char_length(reason) <= 2000",
      name: "commitment_dispositions_reason_length"
    add_index :supplier_commitment_dispositions,
      [ :id, :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_dispositions_on_commitment_owner"
  end

  def create_reopenings!
    create_table :supplier_commitment_reopenings, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_commitment_id, null: false
      table.uuid :supplier_commitment_disposition_id, null: false
      table.string :reason, null: false, limit: 2_000
      table.uuid :actor_id, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_reopenings)
    add_index :supplier_commitment_reopenings,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_reopenings_on_version_owner"
    add_index :supplier_commitment_reopenings, :supplier_commitment_disposition_id,
      unique: true, name: "index_commitment_reopenings_on_disposition"
    add_version_fk(:supplier_commitment_reopenings, "commitment_reopenings_version_fk")
    add_foreign_key :supplier_commitment_reopenings, :supplier_commitments,
      column: [ :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_reopenings_commitment_fk"
    add_foreign_key :supplier_commitment_reopenings, :supplier_commitment_dispositions,
      column: [ :supplier_commitment_disposition_id, :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_reopenings_disposition_fk"
    add_actor_fk(:supplier_commitment_reopenings, "commitment_reopenings_actor_fk")
    add_idempotency_fk(:supplier_commitment_reopenings, "commitment_reopenings_idempotency_fk")
    add_check_constraint :supplier_commitment_reopenings,
      "btrim(reason) <> '' AND char_length(reason) <= 2000",
      name: "commitment_reopenings_reason"
  end

  def create_immutability_triggers!
    %w[
      supplier_commitment_evidence_coverages
      supplier_commitment_evidence_coverage_members
      supplier_commitment_dispositions
      supplier_commitment_reopenings
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

  def identity_indexes(table)
    prefix = {
      supplier_commitment_evidence_coverages: "cmt_ev_cov",
      supplier_commitment_evidence_coverage_members: "cmt_ev_mem",
      supplier_commitment_dispositions: "cmt_disp",
      supplier_commitment_reopenings: "cmt_reopen"
    }.fetch(table.to_sym)
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

  def add_confirmation_fk(table, name)
    add_foreign_key table, :supplier_confirmations,
      column: [ :supplier_confirmation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
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
