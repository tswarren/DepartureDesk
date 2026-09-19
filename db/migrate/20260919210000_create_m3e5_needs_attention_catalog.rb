# frozen_string_literal: true

class CreateM3e5NeedsAttentionCatalog < ActiveRecord::Migration[8.1]
  def change
    add_agency_timing!
    create_findings!
  end

  private

  def add_agency_timing!
    add_column :agencies, :attention_warning_lead_days, :integer
    add_check_constraint :agencies,
      "attention_warning_lead_days IS NULL OR attention_warning_lead_days >= 0",
      name: "agencies_attention_warning_lead_days"
  end

  def create_findings!
    create_table :supplier_attention_findings, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :detector_key, null: false
      table.string :action_group, null: false
      table.string :severity, null: false
      table.string :source_kind, null: false
      table.uuid :source_id, null: false
      table.string :required_action, null: false
      table.string :reason, null: false
      table.string :consequence_summary, null: false
      table.string :primary_path, null: false
      table.timestamptz :attention_at, null: false
      table.timestamptz :overdue_at
      table.timestamptz :rebuilt_at, null: false
      table.string :source_fingerprint, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_attention_findings,
      [ :supplier_arrangement_id, :detector_key, :source_kind, :source_id ],
      unique: true,
      name: "index_attention_findings_on_identity"
    add_index :supplier_attention_findings,
      [ :departure_id, :attention_at, :id ],
      name: "index_attention_findings_on_departure_attention"
    add_index :supplier_attention_findings,
      [ :departure_id, :overdue_at, :id ],
      name: "index_attention_findings_on_departure_overdue"
    add_index :supplier_attention_findings,
      [ :id, :agency_id ],
      unique: true,
      name: "index_attention_findings_on_id_agency"

    add_foreign_key :supplier_attention_findings, :agencies,
      column: :agency_id, name: "attention_findings_agency_fk"
    add_foreign_key :supplier_attention_findings, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "attention_findings_departure_fk"
    add_foreign_key :supplier_attention_findings, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "attention_findings_arrangement_fk"
    add_foreign_key :supplier_attention_findings, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "attention_findings_version_fk"

    add_check_constraint :supplier_attention_findings,
      "detector_key IN (" \
        "'open_commitment_without_future_deadline', " \
        "'actionable_commitment_due_soon', " \
        "'actionable_commitment_overdue', " \
        "'deadline_materialization_incomplete', " \
        "'deposit_calculation_incomplete', " \
        "'exposure_incomplete', " \
        "'unresolved_reservation_response_scope', " \
        "'capacity_override_or_discrepancy'" \
      ")",
      name: "attention_findings_detector_key"
    add_check_constraint :supplier_attention_findings,
      "action_group IN (" \
        "'dispose_or_satisfy_commitment', " \
        "'resolve_deadline', " \
        "'complete_deposit_inputs', " \
        "'inspect_exposure', " \
        "'resolve_reservation_response', " \
        "'review_capacity'" \
      ")",
      name: "attention_findings_action_group"
    add_check_constraint :supplier_attention_findings,
      "severity IN ('attention', 'overdue', 'blocking')",
      name: "attention_findings_severity"
    add_check_constraint :supplier_attention_findings,
      "source_kind IN (" \
        "'supplier_commitment', " \
        "'supplier_deadline_definition', " \
        "'supplier_deadline_occurrence', " \
        "'supplier_deposit_requirement_definition', " \
        "'supplier_exposure_component', " \
        "'supplier_reservation', " \
        "'capacity_pool', " \
        "'capacity_reconciliation'" \
      ")",
      name: "attention_findings_source_kind"
    add_check_constraint :supplier_attention_findings,
      "btrim(required_action) <> '' AND char_length(required_action) <= 160",
      name: "attention_findings_required_action"
    add_check_constraint :supplier_attention_findings,
      "btrim(reason) <> '' AND char_length(reason) <= 240",
      name: "attention_findings_reason"
    add_check_constraint :supplier_attention_findings,
      "btrim(consequence_summary) <> '' AND char_length(consequence_summary) <= 240",
      name: "attention_findings_consequence"
    add_check_constraint :supplier_attention_findings,
      "btrim(primary_path) <> '' AND char_length(primary_path) <= 120",
      name: "attention_findings_primary_path"
    add_check_constraint :supplier_attention_findings,
      "btrim(source_fingerprint) <> '' AND char_length(source_fingerprint) <= 256",
      name: "attention_findings_fingerprint"
    add_check_constraint :supplier_attention_findings,
      "lock_version >= 0",
      name: "attention_findings_lock_version"
  end
end
