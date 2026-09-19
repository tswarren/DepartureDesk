# frozen_string_literal: true

class CreateM3e2DeadlineDefinitionsOccurrences < ActiveRecord::Migration[8.1]
  DEADLINE_TYPES = %w[
    deposit_due option_or_release_date rooming_list_due legal_names_due final_count_due
    final_schedule_or_departure_time_due cancellation_cutoff accessibility_confirmation_due other
  ].freeze

  RULE_SHAPES = %w[
    fixed_date fixed_local_datetime days_before_departure days_after_departure
    hours_before_departure hours_after_departure earlier_of later_of
  ].freeze

  DEFINITION_FREEZE_TABLES = %w[
    supplier_deadline_definitions
    supplier_deadline_definition_coverage_links
    supplier_deadline_commitment_definition_lines
  ].freeze

  def up
    create_deadline_definitions!
    create_coverage_links!
    create_commitment_definition_lines!
    create_occurrences!
    create_projections!
    extend_commitments!
    extend_activations!
    create_immutability_triggers!
    extend_definition_freeze!
  end

  def down
    revert_definition_freeze!
    drop_immutability_triggers!
    revert_activations!
    revert_commitments!
    drop_table :supplier_deadline_projections, if_exists: true
    drop_table :supplier_deadline_occurrences, if_exists: true
    drop_table :supplier_deadline_commitment_definition_lines, if_exists: true
    drop_table :supplier_deadline_definition_coverage_links, if_exists: true
    drop_table :supplier_deadline_definitions, if_exists: true
  end

  private

  def create_deadline_definitions!
    create_table :supplier_deadline_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.string :deadline_type, null: false
      table.string :other_label, limit: 120
      table.string :kind, null: false
      table.string :rule_shape, null: false
      table.jsonb :rule_parameters, null: false, default: {}
      table.string :precision, null: false
      table.string :time_zone, null: false, limit: 64
      table.string :cardinality, null: false, default: "one_shared"
      table.integer :warning_lead_days
      table.integer :position, null: false
      table.string :description, limit: 500
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    identity_indexes(:supplier_deadline_definitions, "ddl_defs")
    add_index :supplier_deadline_definitions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_definitions_on_full_owner"
    add_index :supplier_deadline_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_definitions_on_lineage_owner"
    add_index :supplier_deadline_definitions,
      [ :supplier_arrangement_version_id, :position ],
      unique: true, name: "index_deadline_definitions_on_position"
    add_version_fk(:supplier_deadline_definitions, "deadline_definitions_version_fk")
    add_foreign_key :supplier_deadline_definitions, :supplier_deadline_definitions,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_definitions_copied_from_fk"
    add_check_constraint :supplier_deadline_definitions,
      "deadline_type IN (#{sql_list(DEADLINE_TYPES)})",
      name: "deadline_definitions_type"
    add_check_constraint :supplier_deadline_definitions,
      "(deadline_type = 'other' AND other_label IS NOT NULL AND btrim(other_label) <> '') OR " \
      "(deadline_type <> 'other' AND other_label IS NULL)",
      name: "deadline_definitions_other_label"
    add_check_constraint :supplier_deadline_definitions,
      "kind IN ('actionable', 'informational')",
      name: "deadline_definitions_kind"
    add_check_constraint :supplier_deadline_definitions,
      "rule_shape IN (#{sql_list(RULE_SHAPES)})",
      name: "deadline_definitions_rule_shape"
    add_check_constraint :supplier_deadline_definitions,
      "precision IN ('date_only', 'local_date_time')",
      name: "deadline_definitions_precision"
    add_check_constraint :supplier_deadline_definitions,
      "cardinality IN ('one_shared', 'per_source')",
      name: "deadline_definitions_cardinality"
    add_check_constraint :supplier_deadline_definitions,
      "warning_lead_days IS NULL OR warning_lead_days >= 0",
      name: "deadline_definitions_warning_lead"
    add_check_constraint :supplier_deadline_definitions,
      "position > 0", name: "deadline_definitions_position_positive"
    add_check_constraint :supplier_deadline_definitions,
      "lock_version >= 0", name: "deadline_definitions_lock_version"
    add_check_constraint :supplier_deadline_definitions,
      "btrim(time_zone) <> '' AND char_length(time_zone) <= 64",
      name: "deadline_definitions_time_zone"
    add_check_constraint :supplier_deadline_definitions,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 500)",
      name: "deadline_definitions_description"
    add_check_constraint :supplier_deadline_definitions,
      "other_label IS NULL OR (btrim(other_label) <> '' AND char_length(other_label) <= 120)",
      name: "deadline_definitions_other_label_length"
  end

  def create_coverage_links!
    create_table :supplier_deadline_definition_coverage_links, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deadline_definition_id, null: false
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.integer :position, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_deadline_definition_coverage_links, "ddl_cov")
    add_index :supplier_deadline_definition_coverage_links,
      [ :supplier_deadline_definition_id, :position ],
      unique: true, name: "index_deadline_coverage_links_on_definition_position"
    add_index :supplier_deadline_definition_coverage_links,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_coverage_links_on_full_owner"
    add_version_fk(:supplier_deadline_definition_coverage_links, "deadline_coverage_links_version_fk")
    add_foreign_key :supplier_deadline_definition_coverage_links, :supplier_deadline_definitions,
      column: [ :supplier_deadline_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_coverage_links_definition_fk"
    add_optional_structure_fks(:supplier_deadline_definition_coverage_links, "deadline_coverage")
    # Exactly one coverage target kind; nested parents required for composite FKs.
    add_check_constraint :supplier_deadline_definition_coverage_links,
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
      name: "deadline_coverage_links_exactly_one_target"
    add_check_constraint :supplier_deadline_definition_coverage_links,
      "position > 0", name: "deadline_coverage_links_position_positive"
  end

  def create_commitment_definition_lines!
    create_table :supplier_deadline_commitment_definition_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deadline_definition_id, null: false
      table.uuid :committed_supplier_id, null: false
      table.string :authority_shape, null: false
      table.string :description, null: false, limit: 500
      table.bigint :fixed_quantity
      table.string :quantity_basis
      table.bigint :fixed_amount_minor_units
      table.string :currency, limit: 3
      table.uuid :supplier_cost_source_id
      table.uuid :supplier_cost_definition_id
      table.uuid :supplier_cost_component_id
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    identity_indexes(:supplier_deadline_commitment_definition_lines, "ddl_lines")
    add_index :supplier_deadline_commitment_definition_lines,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_commitment_lines_on_full_owner"
    add_index :supplier_deadline_commitment_definition_lines,
      [ :supplier_deadline_definition_id, :position ],
      unique: true, name: "index_deadline_commitment_lines_on_definition_position"
    add_version_fk(:supplier_deadline_commitment_definition_lines, "deadline_commitment_lines_version_fk")
    add_foreign_key :supplier_deadline_commitment_definition_lines, :supplier_deadline_definitions,
      column: [ :supplier_deadline_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_commitment_lines_definition_fk"
    add_foreign_key :supplier_deadline_commitment_definition_lines, :suppliers,
      column: [ :committed_supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deadline_commitment_lines_supplier_fk"
    add_foreign_key :supplier_deadline_commitment_definition_lines, :supplier_cost_sources,
      column: [ :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_commitment_lines_cost_source_fk"
    add_foreign_key :supplier_deadline_commitment_definition_lines, :supplier_cost_definitions,
      column: [ :supplier_cost_definition_id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_commitment_lines_cost_definition_fk"
    add_foreign_key :supplier_deadline_commitment_definition_lines, :supplier_cost_components,
      column: [ :supplier_cost_component_id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_commitment_lines_cost_component_fk"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "authority_shape IN ('fixed_quantity', 'fixed_contracted_amount')",
      name: "deadline_commitment_lines_authority_shape"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "(authority_shape = 'fixed_quantity' AND fixed_quantity > 0 AND quantity_basis IS NOT NULL " \
        "AND fixed_amount_minor_units IS NULL AND currency IS NULL " \
        "AND supplier_cost_definition_id IS NULL AND supplier_cost_component_id IS NULL) OR " \
      "(authority_shape = 'fixed_contracted_amount' AND fixed_quantity IS NULL AND quantity_basis IS NULL " \
        "AND fixed_amount_minor_units IS NULL AND currency IS NOT NULL " \
        "AND supplier_cost_definition_id IS NOT NULL AND supplier_cost_component_id IS NOT NULL)",
      name: "deadline_commitment_lines_authority_fields"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "quantity_basis IS NULL OR quantity_basis IN ('resource_units', 'traveler_positions')",
      name: "deadline_commitment_lines_quantity_basis"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "currency IS NULL OR currency ~ '^[A-Z]{3}$'",
      name: "deadline_commitment_lines_currency"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "position > 0", name: "deadline_commitment_lines_position_positive"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "lock_version >= 0", name: "deadline_commitment_lines_lock_version"
    add_check_constraint :supplier_deadline_commitment_definition_lines,
      "btrim(description) <> '' AND char_length(description) <= 500",
      name: "deadline_commitment_lines_description"
  end

  def create_occurrences!
    create_table :supplier_deadline_occurrences, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deadline_definition_id, null: false
      table.uuid :supplier_arrangement_activation_id
      table.string :deadline_type, null: false
      table.string :other_label, limit: 120
      table.string :kind, null: false
      table.string :rule_shape, null: false
      table.jsonb :rule_parameters_snapshot, null: false, default: {}
      table.jsonb :rule_inputs_snapshot, null: false, default: {}
      table.string :precision, null: false
      table.string :time_zone, null: false, limit: 64
      table.string :cardinality, null: false
      table.jsonb :coverage_snapshot, null: false, default: []
      table.date :calculated_on
      table.timestamptz :calculated_at
      table.string :materialization_key, null: false, limit: 256
      table.uuid :predecessor_occurrence_id
      table.timestamptz :superseded_at
      table.uuid :actor_id, null: false
      table.timestamptz :materialized_at, null: false
      table.timestamps null: false
    end
    identity_indexes(:supplier_deadline_occurrences, "ddl_occ")
    add_index :supplier_deadline_occurrences,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_occurrences_on_full_owner"
    add_index :supplier_deadline_occurrences,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deadline_occurrences_on_lineage_owner"
    add_index :supplier_deadline_occurrences,
      [ :supplier_arrangement_version_id, :materialization_key ],
      unique: true, name: "index_deadline_occurrences_on_materialization_key"
    add_index :supplier_deadline_occurrences,
      [ :agency_id, :calculated_on, :id ],
      name: "index_deadline_occurrences_on_calculated_on"
    add_index :supplier_deadline_occurrences,
      [ :agency_id, :calculated_at, :id ],
      name: "index_deadline_occurrences_on_calculated_at"
    add_version_fk(:supplier_deadline_occurrences, "deadline_occurrences_version_fk")
    add_foreign_key :supplier_deadline_occurrences, :supplier_deadline_definitions,
      column: [ :supplier_deadline_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_occurrences_definition_fk"
    add_foreign_key :supplier_deadline_occurrences, :supplier_arrangement_activations,
      column: [ :supplier_arrangement_activation_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_occurrences_activation_fk"
    add_foreign_key :supplier_deadline_occurrences, :supplier_deadline_occurrences,
      column: [ :predecessor_occurrence_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_occurrences_predecessor_fk"
    add_foreign_key :supplier_deadline_occurrences, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deadline_occurrences_actor_fk"
    add_check_constraint :supplier_deadline_occurrences,
      "deadline_type IN (#{sql_list(DEADLINE_TYPES)})",
      name: "deadline_occurrences_type"
    add_check_constraint :supplier_deadline_occurrences,
      "kind IN ('actionable', 'informational')",
      name: "deadline_occurrences_kind"
    add_check_constraint :supplier_deadline_occurrences,
      "rule_shape IN (#{sql_list(RULE_SHAPES)})",
      name: "deadline_occurrences_rule_shape"
    add_check_constraint :supplier_deadline_occurrences,
      "precision IN ('date_only', 'local_date_time')",
      name: "deadline_occurrences_precision"
    add_check_constraint :supplier_deadline_occurrences,
      "cardinality IN ('one_shared', 'per_source')",
      name: "deadline_occurrences_cardinality"
    add_check_constraint :supplier_deadline_occurrences,
      "(" \
        "precision = 'date_only' AND calculated_on IS NOT NULL AND calculated_at IS NULL" \
      ") OR (" \
        "precision = 'local_date_time' AND calculated_at IS NOT NULL AND calculated_on IS NULL" \
      ")",
      name: "deadline_occurrences_precision_exclusivity"
    add_check_constraint :supplier_deadline_occurrences,
      "btrim(materialization_key) <> '' AND char_length(materialization_key) <= 256",
      name: "deadline_occurrences_materialization_key"
    add_check_constraint :supplier_deadline_occurrences,
      "btrim(time_zone) <> '' AND char_length(time_zone) <= 64",
      name: "deadline_occurrences_time_zone"
  end

  def create_projections!
    create_table :supplier_deadline_projections, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :supplier_deadline_occurrence_id, null: false
      table.string :status, null: false
      table.date :due_on
      table.timestamptz :due_at
      table.timestamptz :warning_starts_at
      table.timestamptz :overdue_at, null: false
      table.timestamptz :refreshed_at, null: false
      table.timestamptz :next_transition_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index :supplier_deadline_projections, :supplier_deadline_occurrence_id,
      unique: true, name: "index_deadline_projections_on_occurrence"
    add_index :supplier_deadline_projections,
      [ :agency_id, :next_transition_at, :id ],
      name: "index_deadline_projections_on_next_transition"
    add_index :supplier_deadline_projections,
      [ :id, :agency_id ], unique: true, name: "index_deadline_projections_on_id_agency"
    add_foreign_key :supplier_deadline_projections, :agencies, column: :agency_id,
      name: "deadline_projections_agency_fk"
    add_foreign_key :supplier_deadline_projections, :supplier_deadline_occurrences,
      column: [ :supplier_deadline_occurrence_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deadline_projections_occurrence_fk"
    add_check_constraint :supplier_deadline_projections,
      "status IN ('upcoming', 'warning', 'due', 'overdue')",
      name: "deadline_projections_status"
    add_check_constraint :supplier_deadline_projections,
      "lock_version >= 0", name: "deadline_projections_lock_version"
  end

  def extend_commitments!
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_kind"
    change_column_null :supplier_commitments, :supplier_commitment_trigger_definition_id, true
    change_column_null :supplier_commitments, :supplier_confirmation_id, true
    add_column :supplier_commitments, :supplier_deadline_occurrence_id, :uuid
    add_column :supplier_commitments, :supplier_deadline_commitment_definition_line_id, :uuid

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

    execute <<~SQL.squish
      DROP INDEX IF EXISTS index_supplier_commitments_on_confirmation_trigger
    SQL
    add_index :supplier_commitments,
      [ :supplier_confirmation_id, :supplier_commitment_trigger_definition_id ],
      unique: true,
      where: "opening_kind = 'confirmation_trigger'",
      name: "index_supplier_commitments_on_confirmation_trigger"
    add_index :supplier_commitments,
      [ :supplier_deadline_occurrence_id, :supplier_deadline_commitment_definition_line_id ],
      unique: true,
      where: "opening_kind = 'deadline_requirement'",
      name: "index_supplier_commitments_on_deadline_opening"

    add_foreign_key :supplier_commitments, :supplier_deadline_occurrences,
      column: [ :supplier_deadline_occurrence_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_deadline_occurrence_fk"
    add_foreign_key :supplier_commitments, :supplier_deadline_commitment_definition_lines,
      column: [ :supplier_deadline_commitment_definition_line_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_commitments_deadline_line_fk"
  end

  def extend_activations!
    add_column :supplier_arrangement_activations, :elapsed_deadlines_acknowledged, :boolean,
      null: false, default: false
  end

  def create_immutability_triggers!
    execute <<~SQL.squish
      CREATE TRIGGER supplier_deadline_occurrences_reject_update
      BEFORE UPDATE ON supplier_deadline_occurrences
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER supplier_deadline_occurrences_reject_delete
      BEFORE DELETE ON supplier_deadline_occurrences
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
    SQL
    # Allow superseded_at updates only via a dedicated function path: occurrences are
    # append-only for calculated facts; supersession appends a new occurrence and marks
    # the predecessor through a restricted UPDATE of superseded_at alone.
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
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS supplier_deadline_occurrences_reject_update
        ON public.supplier_deadline_occurrences
    SQL
    execute <<~SQL.squish
      CREATE TRIGGER supplier_deadline_occurrences_reject_update
      BEFORE UPDATE ON supplier_deadline_occurrences
      FOR EACH ROW EXECUTE FUNCTION allow_deadline_occurrence_supersession_only();
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
      CREATE OR REPLACE FUNCTION reject_supplier_deadline_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'supplier deadline definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_deadline_definitions_reject_owner_change
        ON public.supplier_deadline_definitions;
      CREATE TRIGGER supplier_deadline_definitions_reject_owner_change
        BEFORE UPDATE ON public.supplier_deadline_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_deadline_definition_owner_change();
    SQL
  end

  def revert_definition_freeze!
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_deadline_definitions_reject_owner_change
        ON public.supplier_deadline_definitions;
      DROP FUNCTION IF EXISTS reject_supplier_deadline_definition_owner_change();
    SQL
    DEFINITION_FREEZE_TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_non_draft_mutation ON public.#{table};
      SQL
    end
  end

  def drop_immutability_triggers!
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS supplier_deadline_occurrences_reject_update
        ON public.supplier_deadline_occurrences
    SQL
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS supplier_deadline_occurrences_reject_delete
        ON public.supplier_deadline_occurrences
    SQL
    execute <<~SQL
      DROP FUNCTION IF EXISTS allow_deadline_occurrence_supersession_only();
    SQL
  end

  def revert_activations!
    remove_column :supplier_arrangement_activations, :elapsed_deadlines_acknowledged
  end

  def revert_commitments!
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_deadline_line_fk"
    remove_foreign_key :supplier_commitments, name: "supplier_commitments_deadline_occurrence_fk"
    remove_index :supplier_commitments, name: "index_supplier_commitments_on_deadline_opening"
    remove_index :supplier_commitments, name: "index_supplier_commitments_on_confirmation_trigger"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_shape"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_opening_kind"
    remove_column :supplier_commitments, :supplier_deadline_commitment_definition_line_id
    remove_column :supplier_commitments, :supplier_deadline_occurrence_id
    change_column_null :supplier_commitments, :supplier_confirmation_id, false
    change_column_null :supplier_commitments, :supplier_commitment_trigger_definition_id, false
    add_check_constraint :supplier_commitments,
      "opening_kind = 'confirmation_trigger'",
      name: "supplier_commitments_opening_kind"
    add_index :supplier_commitments,
      [ :supplier_confirmation_id, :supplier_commitment_trigger_definition_id ],
      unique: true,
      name: "index_supplier_commitments_on_confirmation_trigger"
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
      column: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_item_fk"
    add_foreign_key table, :service_occurrence_definitions,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_occurrence_fk"
    add_foreign_key table, :supplier_resource_definitions,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_resource_fk"
    add_foreign_key table, :capacity_pools,
      column: [ :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_pool_fk"
  end

  def sql_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
