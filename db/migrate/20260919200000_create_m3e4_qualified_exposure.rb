# frozen_string_literal: true

class CreateM3e4QualifiedExposure < ActiveRecord::Migration[8.1]
  def change
    create_qualifications!
    create_components!
    create_summaries!
  end

  private

  def create_qualifications!
    create_table :supplier_exposure_source_qualifications, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :source_kind, null: false
      table.uuid :source_id, null: false
      table.string :qualification_band, null: false
      table.string :qualification_reason, null: false
      table.text :note, null: false
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_exposure_source_qualifications,
      [ :supplier_arrangement_id, :source_kind, :source_id ],
      unique: true,
      name: "index_exposure_qualifications_on_arrangement_source"
    add_index :supplier_exposure_source_qualifications,
      [ :id, :agency_id ],
      unique: true,
      name: "index_exposure_qualifications_on_id_agency"
    add_index :supplier_exposure_source_qualifications,
      [ :id, :supplier_arrangement_id, :agency_id ],
      unique: true,
      name: "index_exposure_qualifications_on_id_arrangement_agency"

    add_foreign_key :supplier_exposure_source_qualifications, :agencies,
      column: :agency_id, name: "exposure_qualifications_agency_fk"
    add_foreign_key :supplier_exposure_source_qualifications, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "exposure_qualifications_departure_fk"
    add_foreign_key :supplier_exposure_source_qualifications, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "exposure_qualifications_arrangement_fk"
    add_foreign_key :supplier_exposure_source_qualifications, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "exposure_qualifications_version_fk"
    add_foreign_key :supplier_exposure_source_qualifications, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "exposure_qualifications_actor_fk"
    add_foreign_key :supplier_exposure_source_qualifications, :agency_command_idempotency_keys,
      column: :agency_command_idempotency_key_id,
      name: "exposure_qualifications_idempotency_fk"

    add_check_constraint :supplier_exposure_source_qualifications,
      "source_kind IN ('supplier_cost_source')",
      name: "exposure_qualifications_source_kind"
    add_check_constraint :supplier_exposure_source_qualifications,
      "qualification_band IN ('guaranteed')",
      name: "exposure_qualifications_band"
    add_check_constraint :supplier_exposure_source_qualifications,
      "btrim(qualification_reason) <> '' AND char_length(qualification_reason) <= 120",
      name: "exposure_qualifications_reason"
    add_check_constraint :supplier_exposure_source_qualifications,
      "btrim(note) <> '' AND char_length(note) <= 2000",
      name: "exposure_qualifications_note"
    add_check_constraint :supplier_exposure_source_qualifications,
      "lock_version >= 0",
      name: "exposure_qualifications_lock_version"
  end

  def create_components!
    create_table :supplier_exposure_components, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :qualification_band, null: false
      table.string :completeness, null: false
      table.string :source_kind, null: false
      table.uuid :source_id, null: false
      table.string :qualification_reason, null: false
      table.bigint :gross_minor_units
      table.bigint :expected_commission_minor_units
      table.bigint :expected_net_minor_units
      table.string :currency, null: false, limit: 3
      table.string :source_fingerprint, null: false
      table.timestamptz :effective_at, null: false
      table.timestamptz :rebuilt_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_exposure_components,
      [ :supplier_arrangement_id, :source_kind, :source_id, :qualification_band, :currency ],
      unique: true,
      name: "index_exposure_components_on_source_identity"
    add_index :supplier_exposure_components,
      [ :supplier_arrangement_id, :qualification_band, :currency, :id ],
      name: "index_exposure_components_on_band_currency"
    add_index :supplier_exposure_components,
      [ :id, :agency_id ],
      unique: true,
      name: "index_exposure_components_on_id_agency"

    add_foreign_key :supplier_exposure_components, :agencies,
      column: :agency_id, name: "exposure_components_agency_fk"
    add_foreign_key :supplier_exposure_components, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "exposure_components_departure_fk"
    add_foreign_key :supplier_exposure_components, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "exposure_components_arrangement_fk"
    add_foreign_key :supplier_exposure_components, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "exposure_components_version_fk"

    add_check_constraint :supplier_exposure_components,
      "qualification_band IN ('guaranteed', 'contingent', 'forecast')",
      name: "exposure_components_band"
    add_check_constraint :supplier_exposure_components,
      "completeness IN ('known', 'incomplete', 'unknown')",
      name: "exposure_components_completeness"
    add_check_constraint :supplier_exposure_components,
      "source_kind IN ('supplier_commitment', 'supplier_cost_source')",
      name: "exposure_components_source_kind"
    add_check_constraint :supplier_exposure_components,
      "currency ~ '^[A-Z]{3}$'",
      name: "exposure_components_currency"
    add_check_constraint :supplier_exposure_components,
      "btrim(qualification_reason) <> '' AND char_length(qualification_reason) <= 120",
      name: "exposure_components_reason"
    add_check_constraint :supplier_exposure_components,
      "btrim(source_fingerprint) <> '' AND char_length(source_fingerprint) <= 256",
      name: "exposure_components_fingerprint"
    add_check_constraint :supplier_exposure_components,
      "(" \
        "completeness = 'known' AND gross_minor_units IS NOT NULL AND gross_minor_units >= 0 AND " \
        "expected_commission_minor_units IS NOT NULL AND expected_commission_minor_units >= 0 AND " \
        "expected_net_minor_units IS NOT NULL" \
      ") OR (" \
        "completeness IN ('incomplete', 'unknown') AND " \
        "gross_minor_units IS NULL AND expected_commission_minor_units IS NULL AND " \
        "expected_net_minor_units IS NULL" \
      ")",
      name: "exposure_components_amount_shape"
    add_check_constraint :supplier_exposure_components,
      "lock_version >= 0",
      name: "exposure_components_lock_version"
  end

  def create_summaries!
    create_table :supplier_exposure_summaries, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.string :qualification_band, null: false
      table.string :completeness, null: false
      table.string :currency, null: false, limit: 3
      table.bigint :gross_minor_units
      table.bigint :expected_commission_minor_units
      table.bigint :expected_net_minor_units
      table.bigint :required_deposit_minor_units
      table.integer :component_count, null: false, default: 0
      table.timestamptz :rebuilt_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_exposure_summaries,
      [ :supplier_arrangement_id, :qualification_band, :currency ],
      unique: true,
      name: "index_exposure_summaries_on_band_currency"
    add_index :supplier_exposure_summaries,
      [ :departure_id, :qualification_band, :currency, :id ],
      name: "index_exposure_summaries_on_departure_band"
    add_index :supplier_exposure_summaries,
      [ :id, :agency_id ],
      unique: true,
      name: "index_exposure_summaries_on_id_agency"

    add_foreign_key :supplier_exposure_summaries, :agencies,
      column: :agency_id, name: "exposure_summaries_agency_fk"
    add_foreign_key :supplier_exposure_summaries, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "exposure_summaries_departure_fk"
    add_foreign_key :supplier_exposure_summaries, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "exposure_summaries_arrangement_fk"
    add_foreign_key :supplier_exposure_summaries, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "exposure_summaries_version_fk"

    add_check_constraint :supplier_exposure_summaries,
      "qualification_band IN ('guaranteed', 'contingent', 'forecast')",
      name: "exposure_summaries_band"
    add_check_constraint :supplier_exposure_summaries,
      "completeness IN ('known', 'incomplete', 'unknown', 'partially_known')",
      name: "exposure_summaries_completeness"
    add_check_constraint :supplier_exposure_summaries,
      "currency ~ '^[A-Z]{3}$'",
      name: "exposure_summaries_currency"
    add_check_constraint :supplier_exposure_summaries,
      "component_count >= 0 AND lock_version >= 0",
      name: "exposure_summaries_counts"
    add_check_constraint :supplier_exposure_summaries,
      "(" \
        "completeness = 'known' AND gross_minor_units IS NOT NULL AND gross_minor_units >= 0 AND " \
        "expected_commission_minor_units IS NOT NULL AND expected_commission_minor_units >= 0 AND " \
        "expected_net_minor_units IS NOT NULL" \
      ") OR (" \
        "completeness = 'partially_known' AND (" \
          "gross_minor_units IS NOT NULL OR expected_commission_minor_units IS NOT NULL OR " \
          "expected_net_minor_units IS NOT NULL" \
        ")" \
      ") OR (" \
        "completeness IN ('incomplete', 'unknown') AND " \
        "gross_minor_units IS NULL AND expected_commission_minor_units IS NULL AND " \
        "expected_net_minor_units IS NULL" \
      ")",
      name: "exposure_summaries_amount_shape"
    add_check_constraint :supplier_exposure_summaries,
      "required_deposit_minor_units IS NULL OR required_deposit_minor_units >= 0",
      name: "exposure_summaries_required_deposit"
  end
end
