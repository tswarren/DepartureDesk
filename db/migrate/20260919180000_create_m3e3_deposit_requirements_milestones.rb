# frozen_string_literal: true

class CreateM3e3DepositRequirementsMilestones < ActiveRecord::Migration[8.1]
  AMOUNT_SHAPES = %w[
    fixed_amount quantity_times_rate percentage_of_cost_sources cumulative_target
  ].freeze

  QUANTITY_BASES = %w[resource_units traveler_positions explicit].freeze
  ROUNDING_SCOPES = %w[aggregate per_source].freeze

  RULE_SHAPES = %w[
    fixed_date fixed_local_datetime days_before_departure days_after_departure
    hours_before_departure hours_after_departure earlier_of later_of
  ].freeze

  MILESTONE_KINDS = %w[names_assigned_to_supplier].freeze

  COMPONENT_KINDS = %w[
    initial_calculation adjustment_increase adjustment_decrease post_satisfaction_increment
  ].freeze

  DEFINITION_FREEZE_TABLES = %w[
    supplier_deposit_requirement_definitions
    supplier_deposit_requirement_definition_coverage_links
    supplier_deposit_requirement_definition_cost_links
  ].freeze

  def up
    create_deposit_definitions!
    create_coverage_links!
    create_cost_links!
    create_tranches!
    create_tranche_components!
    create_external_attestations!
    create_planning_milestones!
    extend_deadline_occurrences_for_deposits!
    extend_commitments!
    extend_dispositions!
    create_immutability_triggers!
    extend_definition_freeze!
  end

  def down
    revert_definition_freeze!
    drop_immutability_triggers!
    revert_dispositions!
    revert_commitments!
    revert_deadline_occurrences_for_deposits!
    drop_table :supplier_planning_milestone_occurrences, if_exists: true
    drop_table :supplier_deposit_external_attestations, if_exists: true
    drop_table :supplier_deposit_requirement_tranche_components, if_exists: true
    drop_table :supplier_deposit_requirement_tranches, if_exists: true
    drop_table :supplier_deposit_requirement_definition_cost_links, if_exists: true
    drop_table :supplier_deposit_requirement_definition_coverage_links, if_exists: true
    drop_table :supplier_deposit_requirement_definitions, if_exists: true
  end

  private

  def create_deposit_definitions!
    create_table :supplier_deposit_requirement_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.string :amount_shape, null: false
      table.bigint :fixed_amount_minor_units
      table.bigint :rate_minor_units
      table.string :quantity_basis
      table.bigint :explicit_quantity
      table.decimal :percentage, precision: 9, scale: 6
      table.string :rounding_scope
      table.bigint :target_amount_minor_units
      table.string :currency, null: false, limit: 3
      table.string :rule_shape, null: false
      table.jsonb :rule_parameters, null: false, default: {}
      table.string :precision, null: false, default: "date_only"
      table.string :time_zone, null: false, limit: 64
      table.integer :position, null: false
      table.string :description, limit: 500
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_requirement_definitions, "dep_defs")
    add_index :supplier_deposit_requirement_definitions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_definitions_on_full_owner"
    add_index :supplier_deposit_requirement_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_definitions_on_lineage_owner"
    add_index :supplier_deposit_requirement_definitions,
      [ :supplier_arrangement_version_id, :position ],
      unique: true, name: "index_deposit_definitions_on_position"
    add_version_fk(:supplier_deposit_requirement_definitions, "deposit_definitions_version_fk")
    add_foreign_key :supplier_deposit_requirement_definitions, :supplier_deposit_requirement_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_definitions_copied_from_fk"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "amount_shape IN (#{sql_list(AMOUNT_SHAPES)})",
      name: "deposit_definitions_amount_shape"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "rule_shape IN (#{sql_list(RULE_SHAPES)})",
      name: "deposit_definitions_rule_shape"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "precision IN ('date_only', 'local_date_time')",
      name: "deposit_definitions_precision"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "currency ~ '^[A-Z]{3}$'",
      name: "deposit_definitions_currency"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "quantity_basis IS NULL OR quantity_basis IN (#{sql_list(QUANTITY_BASES)})",
      name: "deposit_definitions_quantity_basis"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "rounding_scope IS NULL OR rounding_scope IN (#{sql_list(ROUNDING_SCOPES)})",
      name: "deposit_definitions_rounding_scope"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "position > 0", name: "deposit_definitions_position_positive"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "lock_version >= 0", name: "deposit_definitions_lock_version"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "btrim(time_zone) <> '' AND char_length(time_zone) <= 64",
      name: "deposit_definitions_time_zone"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 500)",
      name: "deposit_definitions_description"
    # Shape-specific amount fields.
    add_check_constraint :supplier_deposit_requirement_definitions,
      "(" \
        "amount_shape = 'fixed_amount' AND fixed_amount_minor_units IS NOT NULL " \
        "AND fixed_amount_minor_units >= 0 AND rate_minor_units IS NULL " \
        "AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
        "AND percentage IS NULL AND rounding_scope IS NULL AND target_amount_minor_units IS NULL" \
      ") OR (" \
        "amount_shape = 'quantity_times_rate' AND rate_minor_units IS NOT NULL " \
        "AND rate_minor_units >= 0 AND quantity_basis IS NOT NULL " \
        "AND fixed_amount_minor_units IS NULL AND percentage IS NULL " \
        "AND rounding_scope IS NULL AND target_amount_minor_units IS NULL " \
        "AND ((quantity_basis = 'explicit' AND explicit_quantity IS NOT NULL AND explicit_quantity > 0) OR " \
        "(quantity_basis <> 'explicit' AND explicit_quantity IS NULL))" \
      ") OR (" \
        "amount_shape = 'percentage_of_cost_sources' AND percentage IS NOT NULL " \
        "AND percentage > 0 AND rounding_scope IS NOT NULL " \
        "AND fixed_amount_minor_units IS NULL AND rate_minor_units IS NULL " \
        "AND quantity_basis IS NULL AND explicit_quantity IS NULL AND target_amount_minor_units IS NULL" \
      ") OR (" \
        "amount_shape = 'cumulative_target' AND target_amount_minor_units IS NOT NULL " \
        "AND target_amount_minor_units >= 0 AND fixed_amount_minor_units IS NULL " \
        "AND rate_minor_units IS NULL AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
        "AND percentage IS NULL AND rounding_scope IS NULL" \
      ")",
      name: "deposit_definitions_amount_fields"
  end

  def create_coverage_links!
    create_table :supplier_deposit_requirement_definition_coverage_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_requirement_definition_id, null: false
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.integer :position, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_requirement_definition_coverage_links, "dep_cov")
    add_index :supplier_deposit_requirement_definition_coverage_links,
      [ :supplier_deposit_requirement_definition_id, :position ],
      unique: true, name: "index_deposit_coverage_links_on_definition_position"
    add_index :supplier_deposit_requirement_definition_coverage_links,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_coverage_links_on_full_owner"
    add_version_fk(:supplier_deposit_requirement_definition_coverage_links, "deposit_coverage_links_version_fk")
    add_foreign_key :supplier_deposit_requirement_definition_coverage_links,
      :supplier_deposit_requirement_definitions,
      column: [
        :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_coverage_links_definition_fk"
    add_optional_structure_fks(:supplier_deposit_requirement_definition_coverage_links, "deposit_coverage")
    add_check_constraint :supplier_deposit_requirement_definition_coverage_links,
      "(" \
        "arrangement_item_id IS NOT NULL AND service_occurrence_id IS NULL " \
        "AND supplier_resource_id IS NULL AND capacity_pool_id IS NULL" \
      ") OR (" \
        "arrangement_item_id IS NOT NULL AND service_occurrence_id IS NOT NULL " \
        "AND supplier_resource_id IS NULL AND capacity_pool_id IS NULL" \
      ") OR (" \
        "arrangement_item_id IS NOT NULL AND supplier_resource_id IS NOT NULL " \
        "AND service_occurrence_id IS NULL AND capacity_pool_id IS NULL" \
      ") OR (" \
        "arrangement_item_id IS NOT NULL AND service_occurrence_id IS NOT NULL " \
        "AND supplier_resource_id IS NOT NULL AND capacity_pool_id IS NOT NULL" \
      ")",
      name: "deposit_coverage_links_exactly_one_target"
    add_check_constraint :supplier_deposit_requirement_definition_coverage_links,
      "position > 0", name: "deposit_coverage_links_position_positive"
  end

  def create_cost_links!
    create_table :supplier_deposit_requirement_definition_cost_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_requirement_definition_id, null: false
      table.uuid :supplier_cost_source_id, null: false
      table.uuid :supplier_cost_definition_id
      table.uuid :supplier_cost_component_id
      table.integer :position, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_requirement_definition_cost_links, "dep_cost")
    add_index :supplier_deposit_requirement_definition_cost_links,
      [ :supplier_deposit_requirement_definition_id, :position ],
      unique: true, name: "index_deposit_cost_links_on_definition_position"
    add_index :supplier_deposit_requirement_definition_cost_links,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_cost_links_on_full_owner"
    add_version_fk(:supplier_deposit_requirement_definition_cost_links, "deposit_cost_links_version_fk")
    add_foreign_key :supplier_deposit_requirement_definition_cost_links,
      :supplier_deposit_requirement_definitions,
      column: [
        :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_cost_links_definition_fk"
    add_foreign_key :supplier_deposit_requirement_definition_cost_links, :supplier_cost_sources,
      column: [
        :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_cost_links_cost_source_fk"
    add_foreign_key :supplier_deposit_requirement_definition_cost_links, :supplier_cost_definitions,
      column: [
        :supplier_cost_definition_id, :supplier_cost_source_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      name: "deposit_cost_links_cost_definition_fk"
    add_foreign_key :supplier_deposit_requirement_definition_cost_links, :supplier_cost_components,
      column: [
        :supplier_cost_component_id, :supplier_cost_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      name: "deposit_cost_links_cost_component_fk"
    add_check_constraint :supplier_deposit_requirement_definition_cost_links,
      "position > 0", name: "deposit_cost_links_position_positive"
    add_check_constraint :supplier_deposit_requirement_definition_cost_links,
      "(" \
        "supplier_cost_definition_id IS NULL AND supplier_cost_component_id IS NULL" \
      ") OR (" \
        "supplier_cost_definition_id IS NOT NULL" \
      ")",
      name: "deposit_cost_links_definition_before_component"
  end

  def create_tranches!
    create_table :supplier_deposit_requirement_tranches, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_requirement_definition_id, null: false
      table.uuid :supplier_arrangement_activation_id
      table.string :amount_shape, null: false
      table.jsonb :amount_inputs_snapshot, null: false, default: {}
      table.jsonb :coverage_snapshot, null: false, default: []
      table.bigint :initial_amount_minor_units, null: false
      table.bigint :current_amount_minor_units, null: false
      table.string :currency, null: false, limit: 3
      table.string :materialization_key, null: false, limit: 256
      table.uuid :predecessor_tranche_id
      table.uuid :governing_deadline_occurrence_id
      table.uuid :actor_id, null: false
      table.timestamptz :materialized_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_requirement_tranches, "dep_trn")
    add_index :supplier_deposit_requirement_tranches,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_tranches_on_full_owner"
    add_index :supplier_deposit_requirement_tranches,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_tranches_on_lineage_owner"
    add_index :supplier_deposit_requirement_tranches,
      [ :supplier_arrangement_version_id, :materialization_key ],
      unique: true, name: "index_deposit_tranches_on_materialization_key"
    add_version_fk(:supplier_deposit_requirement_tranches, "deposit_tranches_version_fk")
    add_foreign_key :supplier_deposit_requirement_tranches, :supplier_deposit_requirement_definitions,
      column: [
        :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_tranches_definition_fk"
    add_foreign_key :supplier_deposit_requirement_tranches, :supplier_arrangement_activations,
      column: [
        :supplier_arrangement_activation_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_tranches_activation_fk"
    add_foreign_key :supplier_deposit_requirement_tranches, :supplier_deposit_requirement_tranches,
      column: [ :predecessor_tranche_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_tranches_predecessor_fk"
    add_foreign_key :supplier_deposit_requirement_tranches, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deposit_tranches_actor_fk"
    add_check_constraint :supplier_deposit_requirement_tranches,
      "amount_shape IN (#{sql_list(AMOUNT_SHAPES)})",
      name: "deposit_tranches_amount_shape"
    add_check_constraint :supplier_deposit_requirement_tranches,
      "currency ~ '^[A-Z]{3}$'",
      name: "deposit_tranches_currency"
    add_check_constraint :supplier_deposit_requirement_tranches,
      "initial_amount_minor_units >= 0 AND current_amount_minor_units >= 0",
      name: "deposit_tranches_amounts_nonnegative"
    add_check_constraint :supplier_deposit_requirement_tranches,
      "btrim(materialization_key) <> '' AND char_length(materialization_key) <= 256",
      name: "deposit_tranches_materialization_key"
    add_check_constraint :supplier_deposit_requirement_tranches,
      "lock_version >= 0", name: "deposit_tranches_lock_version"
  end

  def create_tranche_components!
    create_table :supplier_deposit_requirement_tranche_components, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_requirement_tranche_id, null: false
      table.string :component_kind, null: false
      table.bigint :amount_delta_minor_units, null: false
      table.jsonb :calculation_snapshot, null: false, default: {}
      table.string :note, limit: 2000
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_requirement_tranche_components, "dep_cmp")
    add_index :supplier_deposit_requirement_tranche_components,
      [ :supplier_deposit_requirement_tranche_id, :recorded_at, :id ],
      name: "index_deposit_tranche_components_on_timeline"
    add_version_fk(:supplier_deposit_requirement_tranche_components, "deposit_tranche_components_version_fk")
    add_foreign_key :supplier_deposit_requirement_tranche_components,
      :supplier_deposit_requirement_tranches,
      column: [
        :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_tranche_components_tranche_fk"
    add_foreign_key :supplier_deposit_requirement_tranche_components, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deposit_tranche_components_actor_fk"
    add_check_constraint :supplier_deposit_requirement_tranche_components,
      "component_kind IN (#{sql_list(COMPONENT_KINDS)})",
      name: "deposit_tranche_components_kind"
    add_check_constraint :supplier_deposit_requirement_tranche_components,
      "note IS NULL OR (btrim(note) <> '' AND char_length(note) <= 2000)",
      name: "deposit_tranche_components_note"
  end

  def create_external_attestations!
    # Append-only Staff attestation that the open deposit tranche was handled outside
    # DepartureDesk. Never labeled paid. Disposition uses outcome handled_externally.
    create_table :supplier_deposit_external_attestations, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_requirement_tranche_id, null: false
      table.uuid :supplier_commitment_id, null: false
      table.bigint :attested_amount_minor_units, null: false
      table.string :currency, null: false, limit: 3
      table.boolean :confirmed_complete, null: false, default: false
      table.string :note, null: false, limit: 2000
      table.uuid :actor_id, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_deposit_external_attestations, "dep_att")
    add_index :supplier_deposit_external_attestations,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_attestations_on_full_owner"
    add_index :supplier_deposit_external_attestations,
      :supplier_commitment_id,
      unique: true, name: "index_deposit_attestations_on_commitment"
    add_version_fk(:supplier_deposit_external_attestations, "deposit_attestations_version_fk")
    add_foreign_key :supplier_deposit_external_attestations, :supplier_deposit_requirement_tranches,
      column: [
        :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_attestations_tranche_fk"
    add_foreign_key :supplier_deposit_external_attestations, :supplier_commitments,
      column: [
        :supplier_commitment_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_attestations_commitment_fk"
    add_foreign_key :supplier_deposit_external_attestations, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deposit_attestations_actor_fk"
    add_foreign_key :supplier_deposit_external_attestations, :agency_command_idempotency_keys,
      column: :agency_command_idempotency_key_id,
      name: "deposit_attestations_idempotency_fk"
    add_check_constraint :supplier_deposit_external_attestations,
      "confirmed_complete = TRUE",
      name: "deposit_attestations_confirmed_complete"
    add_check_constraint :supplier_deposit_external_attestations,
      "attested_amount_minor_units >= 0",
      name: "deposit_attestations_amount_nonnegative"
    add_check_constraint :supplier_deposit_external_attestations,
      "btrim(note) <> '' AND char_length(note) <= 2000",
      name: "deposit_attestations_note"
    add_check_constraint :supplier_deposit_external_attestations,
      "currency ~ '^[A-Z]{3}$'",
      name: "deposit_attestations_currency"
  end

  def create_planning_milestones!
    create_table :supplier_planning_milestone_occurrences, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.string :kind, null: false
      table.date :occurred_on
      table.timestamptz :occurred_at
      table.string :note, limit: 2000
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    identity_indexes(:supplier_planning_milestone_occurrences, "pln_ms")
    add_index :supplier_planning_milestone_occurrences,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_planning_milestones_on_full_owner"
    add_index :supplier_planning_milestone_occurrences,
      [ :supplier_arrangement_id, :kind, :occurred_on, :id ],
      name: "index_planning_milestones_on_kind_date"
    add_version_fk(:supplier_planning_milestone_occurrences, "planning_milestones_version_fk")
    add_foreign_key :supplier_planning_milestone_occurrences, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "planning_milestones_actor_fk"
    add_foreign_key :supplier_planning_milestone_occurrences, :agency_command_idempotency_keys,
      column: :agency_command_idempotency_key_id,
      name: "planning_milestones_idempotency_fk"
    add_check_constraint :supplier_planning_milestone_occurrences,
      "kind IN (#{sql_list(MILESTONE_KINDS)})",
      name: "planning_milestones_kind"
    add_check_constraint :supplier_planning_milestone_occurrences,
      "(" \
        "occurred_on IS NOT NULL AND occurred_at IS NULL" \
      ") OR (" \
        "occurred_at IS NOT NULL AND occurred_on IS NULL" \
      ")",
      name: "planning_milestones_precision_exclusivity"
    add_check_constraint :supplier_planning_milestone_occurrences,
      "note IS NULL OR (btrim(note) <> '' AND char_length(note) <= 2000)",
      name: "planning_milestones_note"
  end

  def extend_deadline_occurrences_for_deposits!
    change_column_null :supplier_deadline_occurrences, :supplier_deadline_definition_id, true
    add_column :supplier_deadline_occurrences, :supplier_deposit_requirement_definition_id, :uuid

    add_foreign_key :supplier_deadline_occurrences, :supplier_deposit_requirement_definitions,
      column: [
        :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deadline_occurrences_deposit_definition_fk"

    add_check_constraint :supplier_deadline_occurrences,
      "(" \
        "supplier_deadline_definition_id IS NOT NULL AND " \
        "supplier_deposit_requirement_definition_id IS NULL" \
      ") OR (" \
        "supplier_deadline_definition_id IS NULL AND " \
        "supplier_deposit_requirement_definition_id IS NOT NULL AND " \
        "deadline_type = 'deposit_due'" \
      ")",
      name: "deadline_occurrences_source_shape"

    add_foreign_key :supplier_deposit_requirement_tranches, :supplier_deadline_occurrences,
      column: [
        :governing_deadline_occurrence_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_tranches_governing_deadline_fk"
  end

  def extend_commitments!
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_kind"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_shape"
    add_column :supplier_commitments, :supplier_deposit_requirement_tranche_id, :uuid

    add_check_constraint :supplier_commitments,
      "opening_kind IN ('confirmation_trigger', 'deadline_requirement', 'deposit_requirement')",
      name: "supplier_commitments_opening_kind"
    add_check_constraint :supplier_commitments,
      "(" \
        "opening_kind = 'confirmation_trigger' AND " \
        "supplier_commitment_trigger_definition_id IS NOT NULL AND " \
        "supplier_confirmation_id IS NOT NULL AND " \
        "supplier_deadline_occurrence_id IS NULL AND " \
        "supplier_deadline_commitment_definition_line_id IS NULL AND " \
        "supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "opening_kind = 'deadline_requirement' AND " \
        "supplier_commitment_trigger_definition_id IS NULL AND " \
        "supplier_confirmation_id IS NULL AND " \
        "supplier_deadline_occurrence_id IS NOT NULL AND " \
        "supplier_deadline_commitment_definition_line_id IS NOT NULL AND " \
        "supplier_deposit_requirement_tranche_id IS NULL" \
      ") OR (" \
        "opening_kind = 'deposit_requirement' AND " \
        "supplier_commitment_trigger_definition_id IS NULL AND " \
        "supplier_confirmation_id IS NULL AND " \
        "supplier_deadline_occurrence_id IS NULL AND " \
        "supplier_deadline_commitment_definition_line_id IS NULL AND " \
        "supplier_deposit_requirement_tranche_id IS NOT NULL" \
      ")",
      name: "supplier_commitments_opening_shape"

    add_index :supplier_commitments,
      :supplier_deposit_requirement_tranche_id,
      unique: true,
      where: "opening_kind = 'deposit_requirement'",
      name: "index_supplier_commitments_on_deposit_tranche"
    add_foreign_key :supplier_commitments, :supplier_deposit_requirement_tranches,
      column: [
        :supplier_deposit_requirement_tranche_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "supplier_commitments_deposit_tranche_fk"
  end

  def extend_dispositions!
    # Attestation closes deposit commitments without confirmation evidence and without
    # accepted-risk waiver semantics. Note lives in reason; never labeled paid.
    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome"
    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome_proof"
    add_column :supplier_commitment_dispositions, :supplier_deposit_external_attestation_id, :uuid

    add_check_constraint :supplier_commitment_dispositions,
      "outcome IN ('satisfied', 'released', 'waived', 'cancelled', 'superseded', 'handled_externally')",
      name: "commitment_dispositions_outcome"
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

    add_foreign_key :supplier_commitment_dispositions, :supplier_deposit_external_attestations,
      column: [
        :supplier_deposit_external_attestation_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "commitment_dispositions_deposit_attestation_fk"
  end

  def create_immutability_triggers!
    %w[
      supplier_deposit_requirement_tranche_components
      supplier_deposit_external_attestations
      supplier_planning_milestone_occurrences
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

    # Tranche facts are immutable except derived current amount, governing Deadline
    # replacement after a planning milestone, lock_version, and updated_at.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION allow_deposit_tranche_derived_updates_only() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_deposit_requirement_definition_id IS DISTINCT FROM OLD.supplier_deposit_requirement_definition_id
          OR NEW.supplier_arrangement_activation_id IS DISTINCT FROM OLD.supplier_arrangement_activation_id
          OR NEW.amount_shape IS DISTINCT FROM OLD.amount_shape
          OR NEW.amount_inputs_snapshot IS DISTINCT FROM OLD.amount_inputs_snapshot
          OR NEW.coverage_snapshot IS DISTINCT FROM OLD.coverage_snapshot
          OR NEW.initial_amount_minor_units IS DISTINCT FROM OLD.initial_amount_minor_units
          OR NEW.currency IS DISTINCT FROM OLD.currency
          OR NEW.materialization_key IS DISTINCT FROM OLD.materialization_key
          OR NEW.predecessor_tranche_id IS DISTINCT FROM OLD.predecessor_tranche_id
          OR NEW.actor_id IS DISTINCT FROM OLD.actor_id
          OR NEW.materialized_at IS DISTINCT FROM OLD.materialized_at
          OR NEW.created_at IS DISTINCT FROM OLD.created_at
        THEN
          RAISE EXCEPTION 'supplier_deposit_requirement_tranches is append-only except derived fields';
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_deposit_requirement_tranches_reject_update
        ON public.supplier_deposit_requirement_tranches;
      CREATE TRIGGER supplier_deposit_requirement_tranches_reject_update
        BEFORE UPDATE ON public.supplier_deposit_requirement_tranches
        FOR EACH ROW EXECUTE FUNCTION allow_deposit_tranche_derived_updates_only();

      CREATE TRIGGER supplier_deposit_requirement_tranches_reject_delete
        BEFORE DELETE ON public.supplier_deposit_requirement_tranches
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
    SQL

    # Refresh occurrence supersession function to permit deposit source columns.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION allow_deadline_occurrence_supersession_only() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.supplier_deadline_definition_id IS DISTINCT FROM OLD.supplier_deadline_definition_id
          OR NEW.supplier_deposit_requirement_definition_id IS DISTINCT FROM OLD.supplier_deposit_requirement_definition_id
          OR NEW.supplier_arrangement_activation_id IS DISTINCT FROM OLD.supplier_arrangement_activation_id
          OR NEW.deadline_type IS DISTINCT FROM OLD.deadline_type
          OR NEW.other_label IS DISTINCT FROM OLD.other_label
          OR NEW.kind IS DISTINCT FROM OLD.kind
          OR NEW.rule_shape IS DISTINCT FROM OLD.rule_shape
          OR NEW.rule_parameters_snapshot IS DISTINCT FROM OLD.rule_parameters_snapshot
          OR NEW.rule_inputs_snapshot IS DISTINCT FROM OLD.rule_inputs_snapshot
          OR NEW.precision IS DISTINCT FROM OLD.precision
          OR NEW.time_zone IS DISTINCT FROM OLD.time_zone
          OR NEW.cardinality IS DISTINCT FROM OLD.cardinality
          OR NEW.coverage_snapshot IS DISTINCT FROM OLD.coverage_snapshot
          OR NEW.calculated_on IS DISTINCT FROM OLD.calculated_on
          OR NEW.calculated_at IS DISTINCT FROM OLD.calculated_at
          OR NEW.materialization_key IS DISTINCT FROM OLD.materialization_key
          OR NEW.predecessor_occurrence_id IS DISTINCT FROM OLD.predecessor_occurrence_id
          OR NEW.actor_id IS DISTINCT FROM OLD.actor_id
          OR NEW.materialized_at IS DISTINCT FROM OLD.materialized_at
          OR NEW.created_at IS DISTINCT FROM OLD.created_at
        THEN
          RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
        END IF;
        IF OLD.superseded_at IS NOT NULL THEN
          RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
        END IF;
        IF NEW.superseded_at IS NULL THEN
          RAISE EXCEPTION 'supplier_deadline_occurrences is append-only';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def extend_definition_freeze!
    DEFINITION_FREEZE_TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_non_draft_mutation ON public.#{table};
        CREATE TRIGGER #{table}_reject_non_draft_mutation
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();
      SQL
    end

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_supplier_deposit_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'supplier deposit requirement definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_deposit_requirement_definitions_reject_owner_change
        ON public.supplier_deposit_requirement_definitions;
      CREATE TRIGGER supplier_deposit_requirement_definitions_reject_owner_change
        BEFORE UPDATE ON public.supplier_deposit_requirement_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_deposit_definition_owner_change();
    SQL
  end

  def revert_definition_freeze!
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_deposit_requirement_definitions_reject_owner_change
        ON public.supplier_deposit_requirement_definitions;
      DROP FUNCTION IF EXISTS reject_supplier_deposit_definition_owner_change();
    SQL
    DEFINITION_FREEZE_TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_non_draft_mutation ON public.#{table};
      SQL
    end
  end

  def drop_immutability_triggers!
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_deposit_requirement_tranches_reject_update
        ON public.supplier_deposit_requirement_tranches;
      DROP TRIGGER IF EXISTS supplier_deposit_requirement_tranches_reject_delete
        ON public.supplier_deposit_requirement_tranches;
      DROP FUNCTION IF EXISTS allow_deposit_tranche_derived_updates_only();
    SQL
    %w[
      supplier_deposit_requirement_tranche_components
      supplier_deposit_external_attestations
      supplier_planning_milestone_occurrences
    ].each do |table|
      execute <<~SQL.squish
        DROP TRIGGER IF EXISTS #{table}_reject_update ON public.#{table}
      SQL
      execute <<~SQL.squish
        DROP TRIGGER IF EXISTS #{table}_reject_delete ON public.#{table}
      SQL
    end
  end

  def revert_dispositions!
    remove_foreign_key :supplier_commitment_dispositions,
      name: "commitment_dispositions_deposit_attestation_fk"
    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome_proof"
    remove_check_constraint :supplier_commitment_dispositions, name: "commitment_dispositions_outcome"
    remove_column :supplier_commitment_dispositions, :supplier_deposit_external_attestation_id
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
  end

  def revert_commitments!
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_deposit_tranche_fk"
    remove_index :supplier_commitments, name: "index_supplier_commitments_on_deposit_tranche"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_shape"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_kind"
    remove_column :supplier_commitments, :supplier_deposit_requirement_tranche_id
    add_check_constraint :supplier_commitments,
      "opening_kind IN ('confirmation_trigger', 'deadline_requirement')",
      name: "supplier_commitments_opening_kind"
    add_check_constraint :supplier_commitments,
      "(" \
        "opening_kind = 'confirmation_trigger' AND " \
        "supplier_commitment_trigger_definition_id IS NOT NULL AND " \
        "supplier_confirmation_id IS NOT NULL AND " \
        "supplier_deadline_occurrence_id IS NULL AND " \
        "supplier_deadline_commitment_definition_line_id IS NULL" \
      ") OR (" \
        "opening_kind = 'deadline_requirement' AND " \
        "supplier_commitment_trigger_definition_id IS NULL AND " \
        "supplier_confirmation_id IS NULL AND " \
        "supplier_deadline_occurrence_id IS NOT NULL AND " \
        "supplier_deadline_commitment_definition_line_id IS NOT NULL" \
      ")",
      name: "supplier_commitments_opening_shape"
  end

  def revert_deadline_occurrences_for_deposits!
    remove_foreign_key :supplier_deposit_requirement_tranches,
      name: "deposit_tranches_governing_deadline_fk"
    remove_check_constraint :supplier_deadline_occurrences, name: "deadline_occurrences_source_shape"
    remove_foreign_key :supplier_deadline_occurrences, name: "deadline_occurrences_deposit_definition_fk"
    remove_column :supplier_deadline_occurrences, :supplier_deposit_requirement_definition_id
    change_column_null :supplier_deadline_occurrences, :supplier_deadline_definition_id, false
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

  def add_optional_structure_fks(table, prefix)
    add_foreign_key table, :arrangement_item_definitions,
      column: [
        :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      primary_key: [
        :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      name: "#{prefix}_item_fk"
    add_foreign_key table, :service_occurrence_definitions,
      column: [
        :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "#{prefix}_occurrence_fk"
    add_foreign_key table, :supplier_resource_definitions,
      column: [
        :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "#{prefix}_resource_fk"
    add_foreign_key table, :capacity_pools,
      column: [
        :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "#{prefix}_pool_fk"
  end

  def sql_list(values)
    values.map { |value| ActiveRecord::Base.connection.quote(value) }.join(", ")
  end
end
