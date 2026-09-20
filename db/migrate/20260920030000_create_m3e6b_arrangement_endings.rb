# frozen_string_literal: true

class CreateM3e6bArrangementEndings < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_arrangement_endings, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :supplier_arrangement_ending_preview_id, null: false
      table.string :ending_reason, null: false, limit: 80
      table.string :ending_reason_label, limit: 160
      table.text :ending_reason_note
      table.uuid :replacement_arrangement_id
      table.jsonb :selected_cascade_keys, null: false, default: []
      table.jsonb :cascade_manifest, null: false, default: {}
      table.string :preview_digest_sha256, null: false, limit: 64
      table.uuid :actor_id, null: false
      table.timestamptz :ended_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end

    add_index :supplier_arrangement_endings,
      :supplier_arrangement_id, unique: true, name: "index_arrangement_endings_on_arrangement"
    add_index :supplier_arrangement_endings,
      [ :id, :agency_id ], unique: true, name: "index_arrangement_endings_on_id_agency"

    add_foreign_key :supplier_arrangement_endings, :agencies
    add_foreign_key :supplier_arrangement_endings, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "arrangement_endings_departure_fk"
    add_foreign_key :supplier_arrangement_endings, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "arrangement_endings_arrangement_fk"
    add_foreign_key :supplier_arrangement_endings, :supplier_arrangement_versions,
      column: [
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "arrangement_endings_version_fk"
    add_foreign_key :supplier_arrangement_endings, :supplier_arrangement_ending_previews,
      column: [ :supplier_arrangement_ending_preview_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "arrangement_endings_preview_fk"
    add_foreign_key :supplier_arrangement_endings, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "arrangement_endings_actor_fk"
    add_foreign_key :supplier_arrangement_endings, :supplier_arrangements,
      column: :replacement_arrangement_id,
      name: "arrangement_endings_replacement_fk"
    add_foreign_key :supplier_arrangement_endings, :agency_command_idempotency_keys,
      column: [ :agency_command_idempotency_key_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "arrangement_endings_idempotency_fk"

    add_check_constraint :supplier_arrangement_endings,
      "ending_reason IN ('planning_concluded','agreement_expired','not_proceeding_no_live_commitment','replaced','duplicate_or_entered_in_error','other')",
      name: "arrangement_endings_reason_catalog"
    add_check_constraint :supplier_arrangement_endings,
      "((ending_reason = 'other') = (ending_reason_label IS NOT NULL AND ending_reason_note IS NOT NULL))",
      name: "arrangement_endings_other_proof"
    add_check_constraint :supplier_arrangement_endings,
      "((ending_reason = 'replaced') = (replacement_arrangement_id IS NOT NULL))",
      name: "arrangement_endings_replaced_proof"

    execute <<~SQL.squish
      CREATE TRIGGER reject_arrangement_ending_mutation
        BEFORE UPDATE OR DELETE ON supplier_arrangement_endings
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
    SQL
  end
end
