class CreateM3d1ActivationPersistence < ActiveRecord::Migration[8.1]
  LINEAGE_TABLES = %i[
    arrangement_item_definitions service_occurrence_definitions supplier_resource_definitions
    capacity_pair_definitions capacity_pool_definitions supplier_cost_sources
    supplier_cost_definitions supplier_cost_components supplier_cost_component_bases
    supplier_cost_participant_categories supplier_cost_usage_assumptions
    supplier_cost_occupancy_profiles supplier_cost_occupancy_profile_positions
  ].freeze

  def up
    amend_arrangements_and_versions
    add_successor_lineage
    create_supplier_confirmations
    create_supplier_issued_identifiers
    create_supplier_commitment_trigger_definitions
    create_supplier_arrangement_activations
    create_activation_entries
    create_supplier_commitments
    create_confirmation_coverage_links
    create_immutability_triggers
  end

  def down
    execute "DROP FUNCTION IF EXISTS reject_m3d_immutable_mutation() CASCADE"
    drop_table :supplier_confirmation_commitment_links
    drop_table :supplier_confirmation_capacity_event_links
    drop_table :supplier_confirmation_identifier_links
    drop_table :supplier_confirmation_activation_links
    drop_table :supplier_commitments
    drop_table :supplier_arrangement_activation_capacity_entries
    drop_table :supplier_arrangement_activation_cost_selections
    drop_table :supplier_arrangement_activations
    drop_table :supplier_commitment_trigger_definitions
    drop_table :supplier_issued_identifiers
    drop_table :supplier_confirmations
    LINEAGE_TABLES.reverse_each { |table| remove_column table, :copied_from_id }
    remove_foreign_key :supplier_arrangements, name: "supplier_arrangements_governing_version_fk"
    remove_column :supplier_arrangements, :governing_version_id
    remove_column :supplier_arrangement_versions, :copied_from_id
    remove_column :supplier_arrangement_versions, :superseded_at
    remove_column :supplier_arrangement_versions, :activated_at
    remove_index :capacity_events, name: "index_capacity_events_on_version_owner"
    remove_index :capacity_pool_definitions, name: "index_capacity_pool_defs_on_activation_owner"
  end

  private

  def amend_arrangements_and_versions
    add_column :supplier_arrangements, :governing_version_id, :uuid
    add_index :supplier_arrangements, [ :governing_version_id, :id, :departure_id, :agency_id ],
      unique: true, where: "governing_version_id IS NOT NULL",
      name: "index_supplier_arrangements_on_governing_version"
    add_foreign_key :supplier_arrangements, :supplier_arrangement_versions,
      column: [ :governing_version_id, :id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_arrangements_governing_version_fk"
    add_check_constraint :supplier_arrangements,
      "status <> 'active' OR governing_version_id IS NOT NULL",
      name: "supplier_arrangements_active_governing_version"

    add_column :supplier_arrangement_versions, :activated_at, :timestamptz
    add_column :supplier_arrangement_versions, :superseded_at, :timestamptz
    add_column :supplier_arrangement_versions, :copied_from_id, :uuid
    add_index :supplier_arrangement_versions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_arrangement_versions_on_lineage_owner"
    add_foreign_key :supplier_arrangement_versions, :supplier_arrangement_versions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_arrangement_versions_copied_from_fk"
    add_check_constraint :supplier_arrangement_versions,
      "(status = 'draft' AND activated_at IS NULL AND superseded_at IS NULL) OR " \
      "(status = 'activated' AND activated_at IS NOT NULL AND superseded_at IS NULL) OR " \
      "(status = 'superseded' AND activated_at IS NOT NULL AND superseded_at IS NOT NULL AND superseded_at >= activated_at) OR " \
      "(status = 'abandoned' AND activated_at IS NULL AND superseded_at IS NULL)",
      name: "supplier_arrangement_versions_lifecycle_timestamps"
    add_index :capacity_pool_definitions,
      [ :id, :capacity_pool_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_capacity_pool_defs_on_activation_owner"
    add_index :capacity_events,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_capacity_events_on_version_owner"
  end

  def add_successor_lineage
    LINEAGE_TABLES.each do |table|
      add_column table, :copied_from_id, :uuid
      owner_index = lineage_owner_index_name(table)
      add_index table, [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
        unique: true, name: owner_index unless index_exists?(
          table, [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
          unique: true
        )
      add_foreign_key table, table,
        column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
        primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
        name: "#{lineage_prefix(table)}_copied_from_fk"
      add_index table, :copied_from_id, name: "#{lineage_prefix(table)}_copied_from_idx"
    end
  end

  def create_supplier_confirmations
    create_table :supplier_confirmations, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :confirming_supplier_id, null: false
      table.string :evidence_kind, null: false
      table.string :other_evidence_label, limit: 80
      table.date :evidence_on, null: false
      table.string :channel, null: false
      table.string :reference_note, null: false, limit: 500
      table.string :confirmed_without_identifier_reason, limit: 500
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_confirmations)
    add_index :supplier_confirmations,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_confirmations_on_arrangement_owner"
    add_version_fk(:supplier_confirmations)
    add_supplier_fk(:supplier_confirmations, :confirming_supplier_id, "supplier_confirmations_supplier_fk")
    add_actor_fk(:supplier_confirmations)
    add_check_constraint :supplier_confirmations,
      "evidence_kind IN ('contract', 'supplier_confirmation', 'supplier_message', 'supplier_portal', 'verbal_confirmation', 'other')",
      name: "supplier_confirmations_evidence_kind"
    add_check_constraint :supplier_confirmations,
      "(evidence_kind = 'other') = (other_evidence_label IS NOT NULL)",
      name: "supplier_confirmations_other_label_pair"
    text_check(:supplier_confirmations, :other_evidence_label, 80)
    text_check(:supplier_confirmations, :channel, 80, required: true)
    text_check(:supplier_confirmations, :reference_note, 500, required: true)
    text_check(:supplier_confirmations, :confirmed_without_identifier_reason, 500)
  end

  def create_supplier_issued_identifiers
    create_table :supplier_issued_identifiers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_id, null: false
      table.string :issuer_context, null: false, limit: 80
      table.string :identifier_type, null: false
      table.string :other_type_label, limit: 80
      table.string :display_value, null: false, limit: 160
      table.string :normalized_value, null: false, limit: 160
      table.uuid :first_supplier_confirmation_id, null: false
      table.uuid :supersedes_id
      table.timestamptz :superseded_at
      table.timestamps null: false
    end
    identity_indexes(:supplier_issued_identifiers)
    add_index :supplier_issued_identifiers,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_identifiers_on_full_owner"
    add_index :supplier_issued_identifiers,
      [ :agency_id, :supplier_id, :identifier_type, :issuer_context, :normalized_value, :id ],
      name: "index_supplier_identifiers_on_candidate_lookup"
    add_index :supplier_issued_identifiers,
      [ :supplier_arrangement_id, :supplier_id, :identifier_type, :issuer_context, :normalized_value ],
      unique: true, where: "superseded_at IS NULL",
      name: "index_supplier_identifiers_on_active_owner_value"
    add_arrangement_fk(:supplier_issued_identifiers)
    add_supplier_fk(:supplier_issued_identifiers, :supplier_id, "supplier_identifiers_supplier_fk")
    add_foreign_key :supplier_issued_identifiers, :supplier_confirmations,
      column: [ :first_supplier_confirmation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_identifiers_first_confirmation_fk"
    add_foreign_key :supplier_issued_identifiers, :supplier_issued_identifiers,
      column: [ :supersedes_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_identifiers_supersedes_fk"
    add_check_constraint :supplier_issued_identifiers,
      "identifier_type IN ('group_number', 'reservation_number', 'confirmation_number', 'policy_number', 'other')",
      name: "supplier_identifiers_type"
    add_check_constraint :supplier_issued_identifiers,
      "(identifier_type = 'other') = (other_type_label IS NOT NULL)",
      name: "supplier_identifiers_other_label_pair"
    add_check_constraint :supplier_issued_identifiers,
      "(supersedes_id IS NULL) = (superseded_at IS NULL)",
      name: "supplier_identifiers_supersession_pair"
    text_check(:supplier_issued_identifiers, :issuer_context, 80, required: true)
    text_check(:supplier_issued_identifiers, :other_type_label, 80)
    text_check(:supplier_issued_identifiers, :display_value, 160, required: true)
    text_check(:supplier_issued_identifiers, :normalized_value, 160, required: true)
  end

  def create_supplier_commitment_trigger_definitions
    create_table :supplier_commitment_trigger_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.uuid :supplier_cost_source_id
      table.uuid :committed_supplier_id, null: false
      table.string :trigger_kind, null: false
      table.string :authority_shape, null: false
      table.string :description, null: false, limit: 500
      table.bigint :fixed_quantity
      table.string :quantity_basis
      table.bigint :fixed_amount_minor_units
      table.string :currency, limit: 3
      table.uuid :supplier_cost_definition_id
      table.uuid :supplier_cost_component_id
      table.uuid :copied_from_id
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitment_trigger_definitions)
    add_index :supplier_commitment_trigger_definitions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_triggers_on_full_owner"
    add_index :supplier_commitment_trigger_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_commitment_triggers_on_lineage_owner"
    add_index :supplier_commitment_trigger_definitions,
      [ :supplier_arrangement_version_id, :position ],
      unique: true, name: "index_commitment_triggers_on_position"
    add_version_fk(:supplier_commitment_trigger_definitions)
    add_optional_exact_structure_fks(:supplier_commitment_trigger_definitions)
    add_supplier_fk(:supplier_commitment_trigger_definitions, :committed_supplier_id, "commitment_triggers_supplier_fk")
    add_foreign_key :supplier_commitment_trigger_definitions, :supplier_cost_sources,
      column: [ :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_triggers_cost_source_fk"
    add_foreign_key :supplier_commitment_trigger_definitions, :supplier_cost_definitions,
      column: [ :supplier_cost_definition_id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_triggers_cost_definition_fk"
    add_foreign_key :supplier_commitment_trigger_definitions, :supplier_cost_components,
      column: [ :supplier_cost_component_id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_triggers_cost_component_fk"
    add_foreign_key :supplier_commitment_trigger_definitions, :supplier_commitment_trigger_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "commitment_triggers_copied_from_fk"
    add_trigger_checks
  end

  def create_supplier_arrangement_activations
    create_table :supplier_arrangement_activations, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.string :activation_kind, null: false
      table.uuid :predecessor_version_id
      table.uuid :predecessor_activation_id
      table.uuid :supplier_confirmation_id, null: false
      table.uuid :actor_id, null: false
      table.timestamptz :activated_at, null: false
      table.string :coverage_attestation_version, null: false, limit: 40
      table.string :coverage_fingerprint, null: false, limit: 128
      table.boolean :provisional_costs_acknowledged, null: false, default: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_arrangement_activations)
    add_index :supplier_arrangement_activations, :supplier_arrangement_version_id,
      unique: true, name: "index_arrangement_activations_on_version"
    add_version_fk(:supplier_arrangement_activations)
    add_actor_fk(:supplier_arrangement_activations)
    add_foreign_key :supplier_arrangement_activations, :supplier_confirmations,
      column: [ :supplier_confirmation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "arrangement_activations_confirmation_fk"
    add_foreign_key :supplier_arrangement_activations, :supplier_arrangement_versions,
      column: [ :predecessor_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "arrangement_activations_predecessor_version_fk"
    add_foreign_key :supplier_arrangement_activations, :supplier_arrangement_activations,
      column: [ :predecessor_activation_id, :predecessor_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "arrangement_activations_predecessor_activation_fk"
    add_check_constraint :supplier_arrangement_activations,
      "activation_kind IN ('first', 'successor')",
      name: "arrangement_activations_kind"
    add_check_constraint :supplier_arrangement_activations,
      "(activation_kind = 'first' AND predecessor_version_id IS NULL AND predecessor_activation_id IS NULL) OR " \
      "(activation_kind = 'successor' AND predecessor_version_id IS NOT NULL AND predecessor_activation_id IS NOT NULL)",
      name: "arrangement_activations_predecessor_shape"
    text_check(:supplier_arrangement_activations, :coverage_attestation_version, 40, required: true)
    text_check(:supplier_arrangement_activations, :coverage_fingerprint, 128, required: true)
  end

  def create_activation_entries
    create_table :supplier_arrangement_activation_cost_selections, id: :uuid, default: -> { "uuidv7()" } do |table|
      activation_owner_columns(table)
      table.uuid :supplier_cost_source_id, null: false
      table.uuid :supplier_cost_definition_id, null: false
      table.string :selection_kind, null: false
      table.timestamps null: false
    end
    activation_entry_indexes(:supplier_arrangement_activation_cost_selections, :supplier_cost_source_id, "activation_cost_selections")
    add_activation_fk(:supplier_arrangement_activation_cost_selections)
    add_foreign_key :supplier_arrangement_activation_cost_selections, :supplier_cost_definitions,
      column: [ :supplier_cost_definition_id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "activation_cost_selections_definition_fk"
    add_check_constraint :supplier_arrangement_activation_cost_selections,
      "selection_kind IN ('contracted', 'provisional_estimate')",
      name: "activation_cost_selections_kind"

    create_table :supplier_arrangement_activation_capacity_entries, id: :uuid, default: -> { "uuidv7()" } do |table|
      activation_owner_columns(table)
      table.uuid :capacity_pool_definition_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.uuid :establishment_event_id
      table.string :entry_kind, null: false
      table.timestamps null: false
    end
    activation_entry_indexes(:supplier_arrangement_activation_capacity_entries, :capacity_pool_definition_id, "activation_capacity_entries")
    add_activation_fk(:supplier_arrangement_activation_capacity_entries)
    add_foreign_key :supplier_arrangement_activation_capacity_entries, :capacity_pool_definitions,
      column: [ :capacity_pool_definition_id, :capacity_pool_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :capacity_pool_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "activation_capacity_entries_pool_definition_fk"
    add_foreign_key :supplier_arrangement_activation_capacity_entries, :capacity_events,
      column: [ :establishment_event_id, :capacity_pool_id, :agency_id ],
      primary_key: [ :id, :capacity_pool_id, :agency_id ],
      name: "activation_capacity_entries_event_fk"
    add_check_constraint :supplier_arrangement_activation_capacity_entries,
      "entry_kind IN ('established', 'carried', 'nonnumeric')",
      name: "activation_capacity_entries_kind"
    add_check_constraint :supplier_arrangement_activation_capacity_entries,
      "(entry_kind = 'established') = (establishment_event_id IS NOT NULL)",
      name: "activation_capacity_entries_event_shape"
  end

  def create_supplier_commitments
    create_table :supplier_commitments, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_arrangement_activation_id
      table.uuid :supplier_commitment_trigger_definition_id, null: false
      table.uuid :supplier_confirmation_id, null: false
      table.uuid :committed_supplier_id, null: false
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.uuid :supplier_cost_source_id
      table.string :commitment_type, null: false
      table.string :description, null: false, limit: 500
      table.bigint :quantity
      table.string :quantity_basis
      table.bigint :amount_minor_units
      table.string :currency, limit: 3
      table.string :calculation_snapshot, null: false, limit: 2_000
      table.uuid :actor_id, null: false
      table.timestamptz :opened_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_commitments)
    add_index :supplier_commitments,
      [ :supplier_confirmation_id, :supplier_commitment_trigger_definition_id ],
      unique: true, name: "index_supplier_commitments_on_confirmation_trigger"
    add_index :supplier_commitments, [ :agency_id, :committed_supplier_id, :opened_at, :id ],
      name: "index_supplier_commitments_on_supplier_blocker"
    add_version_fk(:supplier_commitments)
    add_optional_exact_structure_fks(:supplier_commitments)
    add_supplier_fk(:supplier_commitments, :committed_supplier_id, "supplier_commitments_supplier_fk")
    add_actor_fk(:supplier_commitments)
    add_foreign_key :supplier_commitments, :supplier_commitment_trigger_definitions,
      column: [ :supplier_commitment_trigger_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_trigger_fk"
    add_foreign_key :supplier_commitments, :supplier_confirmations,
      column: [ :supplier_confirmation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_confirmation_fk"
    add_foreign_key :supplier_commitments, :supplier_arrangement_activations,
      column: [ :supplier_arrangement_activation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_activation_fk"
    add_foreign_key :supplier_commitments, :agency_command_idempotency_keys,
      column: [ :agency_command_idempotency_key_id, :agency_id ],
      primary_key: [ :id, :agency_id ], name: "supplier_commitments_idempotency_fk"
    add_check_constraint :supplier_commitments,
      "commitment_type IN ('quantity', 'monetary', 'quantity_and_monetary')",
      name: "supplier_commitments_type"
    add_check_constraint :supplier_commitments,
      "(quantity IS NULL) = (quantity_basis IS NULL) AND (quantity IS NULL OR quantity > 0)",
      name: "supplier_commitments_quantity_shape"
    add_check_constraint :supplier_commitments,
      "(amount_minor_units IS NULL) = (currency IS NULL) AND (amount_minor_units IS NULL OR amount_minor_units >= 0)",
      name: "supplier_commitments_money_shape"
    add_check_constraint :supplier_commitments,
      "(commitment_type = 'quantity' AND quantity IS NOT NULL AND amount_minor_units IS NULL) OR " \
      "(commitment_type = 'monetary' AND quantity IS NULL AND amount_minor_units IS NOT NULL) OR " \
      "(commitment_type = 'quantity_and_monetary' AND quantity IS NOT NULL AND amount_minor_units IS NOT NULL)",
      name: "supplier_commitments_authority_shape"
    text_check(:supplier_commitments, :description, 500, required: true)
    text_check(:supplier_commitments, :calculation_snapshot, 2_000, required: true)
  end

  def create_confirmation_coverage_links
    create_coverage_link(:supplier_confirmation_activation_links, :supplier_arrangement_activation_id,
      :supplier_arrangement_activations, "confirmation_activation_links")
    create_coverage_link(:supplier_confirmation_identifier_links, :supplier_issued_identifier_id,
      :supplier_issued_identifiers, "confirmation_identifier_links", versioned: false)
    create_coverage_link(:supplier_confirmation_capacity_event_links, :capacity_event_id,
      :capacity_events, "confirmation_capacity_event_links", compact_owner: true)
    create_coverage_link(:supplier_confirmation_commitment_links, :supplier_commitment_id,
      :supplier_commitments, "confirmation_commitment_links")
  end

  def create_coverage_link(table_name, target_column, target_table, prefix, versioned: true, compact_owner: false)
    create_table table_name, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_confirmation_id, null: false
      table.uuid target_column, null: false
      table.timestamps null: false
    end
    identity_indexes(table_name)
    add_index table_name, [ :supplier_confirmation_id, target_column ],
      unique: true, name: "index_#{prefix}_on_pair"
    add_version_fk(table_name)
    add_foreign_key table_name, :supplier_confirmations,
      column: [ :supplier_confirmation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_confirmation_fk"
    target_columns = if compact_owner
      [ target_column, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ]
    elsif versioned
      [ target_column, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ]
    else
      [ target_column, :supplier_arrangement_id, :departure_id, :agency_id ]
    end
    primary_columns = if versioned || compact_owner
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ]
    else
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ]
    end
    add_foreign_key table_name, target_table,
      column: target_columns, primary_key: primary_columns,
      name: "#{prefix}_target_fk"
  end

  def add_trigger_checks
    table = :supplier_commitment_trigger_definitions
    add_check_constraint table,
      "trigger_kind IN ('arrangement_confirmation', 'reservation_confirmation')",
      name: "commitment_triggers_kind"
    add_check_constraint table,
      "authority_shape IN ('fixed_quantity', 'confirmed_quantity', 'fixed_contracted_amount', 'confirmed_amount', 'contracted_unit_rate_times_confirmed_quantity')",
      name: "commitment_triggers_authority_shape"
    add_check_constraint table,
      "(service_occurrence_id IS NULL OR arrangement_item_id IS NOT NULL) AND " \
      "(supplier_resource_id IS NULL OR arrangement_item_id IS NOT NULL) AND " \
      "(capacity_pool_id IS NULL OR (arrangement_item_id IS NOT NULL AND service_occurrence_id IS NOT NULL AND supplier_resource_id IS NOT NULL))",
      name: "commitment_triggers_scope_shape"
    add_check_constraint table,
      "(authority_shape = 'fixed_quantity' AND fixed_quantity > 0 AND quantity_basis IS NOT NULL AND fixed_amount_minor_units IS NULL AND currency IS NULL AND supplier_cost_definition_id IS NULL AND supplier_cost_component_id IS NULL) OR " \
      "(authority_shape = 'confirmed_quantity' AND fixed_quantity IS NULL AND quantity_basis IS NOT NULL AND fixed_amount_minor_units IS NULL AND currency IS NULL AND supplier_cost_definition_id IS NULL AND supplier_cost_component_id IS NULL) OR " \
      "(authority_shape = 'fixed_contracted_amount' AND fixed_quantity IS NULL AND quantity_basis IS NULL AND fixed_amount_minor_units IS NULL AND currency IS NOT NULL AND supplier_cost_definition_id IS NOT NULL AND supplier_cost_component_id IS NOT NULL) OR " \
      "(authority_shape = 'confirmed_amount' AND fixed_quantity IS NULL AND quantity_basis IS NULL AND fixed_amount_minor_units IS NULL AND currency IS NOT NULL AND supplier_cost_definition_id IS NULL AND supplier_cost_component_id IS NULL) OR " \
      "(authority_shape = 'contracted_unit_rate_times_confirmed_quantity' AND fixed_quantity IS NULL AND quantity_basis IS NOT NULL AND fixed_amount_minor_units IS NULL AND currency IS NOT NULL AND supplier_cost_definition_id IS NOT NULL AND supplier_cost_component_id IS NOT NULL)",
      name: "commitment_triggers_authority_fields"
    add_check_constraint table,
      "quantity_basis IS NULL OR quantity_basis IN ('resource_units', 'traveler_positions')",
      name: "commitment_triggers_quantity_basis"
    add_check_constraint table, "currency IS NULL OR currency ~ '^[A-Z]{3}$'",
      name: "commitment_triggers_currency"
    add_check_constraint table, "position > 0", name: "commitment_triggers_position_positive"
    add_check_constraint table, "lock_version >= 0", name: "commitment_triggers_lock_version"
    text_check(table, :description, 500, required: true)
  end

  def create_immutability_triggers
    execute <<~SQL
      CREATE FUNCTION reject_m3d_immutable_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
      END;
      $$;
    SQL
    immutable_tables = %i[
      supplier_confirmations supplier_issued_identifiers supplier_arrangement_activations
      supplier_arrangement_activation_cost_selections supplier_arrangement_activation_capacity_entries
      supplier_commitments supplier_confirmation_activation_links supplier_confirmation_identifier_links
      supplier_confirmation_capacity_event_links supplier_confirmation_commitment_links
    ]
    immutable_tables.each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_update BEFORE UPDATE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
        CREATE TRIGGER #{table}_reject_delete BEFORE DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      SQL
    end
  end

  def owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
  end

  def activation_owner_columns(table)
    owner_columns(table)
    table.uuid :supplier_arrangement_activation_id, null: false
  end

  def identity_indexes(table)
    prefix = short_prefix(table)
    add_index table, [ :id, :agency_id ], unique: true,
      name: "index_#{prefix}_on_id_agency"
    add_index table, [ :id, :departure_id, :agency_id ], unique: true,
      name: "index_#{prefix}_on_id_departure_agency"
    if column_exists?(table, :supplier_arrangement_version_id)
      add_index table,
        [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
        unique: true, name: "index_#{prefix}_on_version_owner"
    end
  end

  def activation_entry_indexes(table, unique_column, prefix)
    identity_indexes(table)
    add_index table, [ :supplier_arrangement_activation_id, unique_column ],
      unique: true, name: "index_#{prefix}_on_activation_entry"
  end

  def add_version_fk(table)
    add_foreign_key table, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_version_fk"
  end

  def add_arrangement_fk(table)
    add_foreign_key table, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_arrangement_fk"
  end

  def add_activation_fk(table)
    add_foreign_key table, :supplier_arrangement_activations,
      column: [ :supplier_arrangement_activation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_activation_fk"
  end

  def add_supplier_fk(table, column, name)
    add_foreign_key table, :suppliers,
      column: [ column, :agency_id ], primary_key: [ :id, :agency_id ], name: name
  end

  def add_actor_fk(table)
    add_foreign_key table, :agency_users,
      column: [ :actor_id, :agency_id ], primary_key: [ :id, :agency_id ],
      name: "#{short_prefix(table)}_actor_fk"
  end

  def add_optional_exact_structure_fks(table)
    add_foreign_key table, :arrangement_item_definitions,
      column: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_item_definition_fk"
    add_foreign_key table, :service_occurrence_definitions,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_occurrence_definition_fk"
    add_foreign_key table, :supplier_resource_definitions,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_resource_definition_fk"
    add_foreign_key table, :capacity_pools,
      column: [ :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{short_prefix(table)}_capacity_pool_fk"
  end

  def text_check(table, column, limit, required: false)
    expression = "btrim(#{column}) <> '' AND char_length(#{column}) <= #{limit}"
    expression = "#{column} IS NULL OR (#{expression})" unless required
    add_check_constraint table, expression, name: "#{short_prefix(table)}_#{column}"
  end

  def short_prefix(table)
    {
      supplier_arrangement_activations: "arrangement_activations",
      supplier_arrangement_activation_cost_selections: "activation_cost_selections",
      supplier_arrangement_activation_capacity_entries: "activation_capacity_entries",
      supplier_commitment_trigger_definitions: "commitment_triggers",
      supplier_confirmation_activation_links: "confirmation_activation_links",
      supplier_confirmation_identifier_links: "confirmation_identifier_links",
      supplier_confirmation_capacity_event_links: "confirmation_capacity_event_links",
      supplier_confirmation_commitment_links: "confirmation_commitment_links",
      supplier_issued_identifiers: "supplier_identifiers"
    }.fetch(table.to_sym, table.to_s)
  end

  def lineage_prefix(table)
    {
      arrangement_item_definitions: "item_definitions",
      service_occurrence_definitions: "occurrence_definitions",
      supplier_resource_definitions: "resource_definitions",
      capacity_pair_definitions: "capacity_pairs",
      capacity_pool_definitions: "capacity_pool_defs",
      supplier_cost_participant_categories: "supplier_cost_categories",
      supplier_cost_usage_assumptions: "supplier_cost_assumptions",
      supplier_cost_occupancy_profiles: "supplier_cost_profiles",
      supplier_cost_occupancy_profile_positions: "supplier_cost_profile_positions"
    }.fetch(table, table.to_s)
  end

  def lineage_owner_index_name(table)
    "#{lineage_prefix(table)}_lineage_owner_idx"
  end
end
