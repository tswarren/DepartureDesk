# frozen_string_literal: true

class CreateM3e6aEndingAuthorityAndPreviews < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_arrangements, :ended_at, :timestamptz
    add_check_constraint :supplier_arrangements,
      "((status = 'ended') = (ended_at IS NOT NULL))",
      name: "supplier_arrangements_ended_at_pair"

    create_table :supplier_arrangement_ending_previews, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.integer :arrangement_lock_version, null: false
      table.integer :version_lock_version, null: false
      table.uuid :actor_id, null: false
      table.jsonb :payload, null: false, default: {}
      table.string :digest_sha256, null: false, limit: 64
      table.string :token_digest, null: false, limit: 64
      table.timestamptz :expires_at, null: false
      table.string :ending_reason, limit: 80
      table.string :ending_reason_label, limit: 160
      table.text :ending_reason_note
      table.uuid :replacement_arrangement_id
      table.jsonb :selected_cascade_keys, null: false, default: []
      table.jsonb :required_acknowledgments, null: false, default: []
      table.timestamps null: false
    end

    add_index :supplier_arrangement_ending_previews,
      [ :id, :agency_id ], unique: true, name: "index_ending_previews_on_id_agency"
    add_index :supplier_arrangement_ending_previews,
      [ :supplier_arrangement_id, :expires_at ],
      name: "index_ending_previews_on_arrangement_expires"
    add_index :supplier_arrangement_ending_previews,
      :token_digest, unique: true, name: "index_ending_previews_on_token_digest"

    add_foreign_key :supplier_arrangement_ending_previews, :agencies
    add_foreign_key :supplier_arrangement_ending_previews, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "ending_previews_departure_fk"
    add_foreign_key :supplier_arrangement_ending_previews, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "ending_previews_arrangement_fk"
    add_foreign_key :supplier_arrangement_ending_previews, :supplier_arrangement_versions,
      column: [
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "ending_previews_version_fk"
    add_foreign_key :supplier_arrangement_ending_previews, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "ending_previews_actor_fk"
    add_foreign_key :supplier_arrangement_ending_previews, :supplier_arrangements,
      column: :replacement_arrangement_id,
      name: "ending_previews_replacement_fk"

    add_check_constraint :supplier_arrangement_ending_previews,
      "char_length(digest_sha256) = 64 AND digest_sha256 ~ '^[0-9a-f]+$'",
      name: "ending_previews_digest_shape"
    add_check_constraint :supplier_arrangement_ending_previews,
      "char_length(token_digest) = 64 AND token_digest ~ '^[0-9a-f]+$'",
      name: "ending_previews_token_digest_shape"
  end
end
