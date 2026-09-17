class CreateSupplierCapacity < ActiveRecord::Migration[8.1]
  CAPACITY_MANAGEMENT = %w[managed unmanaged].freeze
  PAIR_CLASSIFICATIONS = %w[pooled not_applicable].freeze
  INVENTORY_MODES = %w[block allotment on_request externally_managed].freeze
  MEASUREMENT_BASES = %w[resource_units traveler_positions].freeze
  EVIDENCE_KINDS = %w[
    contract
    supplier_confirmation
    supplier_message
    supplier_portal
    verbal_confirmation
    other
  ].freeze
  EVENT_TYPES = %w[
    established
    increased
    released
    reinstated
    withdrawn
    corrected_up
    corrected_down
  ].freeze

  def up
    amend_arrangement_item_definitions
    add_m3a_exact_version_keys
    create_capacity_pair_definitions
    create_capacity_pools
    create_capacity_pool_definitions
    create_capacity_events
    create_capacity_projections
    create_capacity_reconciliations
    create_capacity_reconciliation_resolutions
    add_capacity_event_reconciliation_fk
    create_capacity_triggers
  end

  def down
    drop_table :capacity_reconciliation_resolutions
    remove_foreign_key :capacity_events, name: "capacity_events_reconciliation_fk"
    drop_table :capacity_reconciliations
    drop_table :capacity_projections
    drop_table :capacity_events
    drop_table :capacity_pool_definitions
    drop_table :capacity_pools
    drop_table :capacity_pair_definitions

    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_capacity_pair_for_cancelled_occurrence();
      DROP FUNCTION IF EXISTS reject_invalid_capacity_pool_zone();
      DROP FUNCTION IF EXISTS reject_capacity_pair_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_capacity_pool_owner_change();
      DROP FUNCTION IF EXISTS reject_capacity_pool_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_capacity_event_mutation();
      DROP FUNCTION IF EXISTS reject_capacity_projection_owner_change();
      DROP FUNCTION IF EXISTS reject_capacity_reconciliation_mutation();
      DROP FUNCTION IF EXISTS reject_capacity_reconciliation_resolution_mutation();
    SQL

    remove_index :agency_command_idempotency_keys,
      name: "index_idempotency_keys_on_id_and_agency_id"
    remove_index :arrangement_item_definitions,
      name: "index_item_definitions_on_exact_version_owner"
    remove_index :service_occurrence_definitions,
      name: "index_occurrence_definitions_on_exact_version_owner"
    remove_index :supplier_resource_definitions,
      name: "index_resource_definitions_on_exact_version_owner"

    remove_check_constraint :arrangement_item_definitions,
      name: "arrangement_item_definitions_capacity_management"
    remove_column :arrangement_item_definitions, :capacity_management
  end

  private

  def amend_arrangement_item_definitions
    add_column :arrangement_item_definitions, :capacity_management, :string
    add_check_constraint :arrangement_item_definitions,
      "capacity_management IS NULL OR capacity_management IN (#{quoted_values(CAPACITY_MANAGEMENT)})",
      name: "arrangement_item_definitions_capacity_management"
  end

  def add_m3a_exact_version_keys
    add_index :agency_command_idempotency_keys, [ :id, :agency_id ],
      unique: true,
      name: "index_idempotency_keys_on_id_and_agency_id"

    add_index :arrangement_item_definitions,
      [
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      unique: true,
      name: "index_item_definitions_on_exact_version_owner"

    add_index :service_occurrence_definitions,
      [
        :service_occurrence_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      unique: true,
      name: "index_occurrence_definitions_on_exact_version_owner"

    add_index :supplier_resource_definitions,
      [
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      unique: true,
      name: "index_resource_definitions_on_exact_version_owner"
  end

  def create_capacity_pair_definitions
    create_table :capacity_pair_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_version_owner_columns(table)
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.string :classification, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_pair_indexes
    add_version_fk(:capacity_pair_definitions)
    add_item_fk(:capacity_pair_definitions)
    add_occurrence_fk(:capacity_pair_definitions)
    add_resource_fk(:capacity_pair_definitions)
    add_item_definition_fk(:capacity_pair_definitions)
    add_occurrence_definition_fk(:capacity_pair_definitions)
    add_resource_definition_fk(:capacity_pair_definitions)
    add_check_constraint :capacity_pair_definitions,
      "classification IN (#{quoted_values(PAIR_CLASSIFICATIONS)})",
      name: "capacity_pair_definitions_classification"
    add_check_constraint :capacity_pair_definitions,
      "lock_version >= 0",
      name: "capacity_pair_definitions_lock_version"
  end

  def add_pair_indexes
    add_index :capacity_pair_definitions, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_pairs_on_id_and_agency_id"
    add_index :capacity_pair_definitions, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_capacity_pairs_on_id_departure_agency"
    add_index :capacity_pair_definitions,
      [
        :id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      unique: true,
      name: "index_capacity_pairs_on_full_owner"
    add_index :capacity_pair_definitions,
      [ :supplier_arrangement_version_id, :service_occurrence_id, :supplier_resource_id ],
      unique: true,
      name: "index_capacity_pairs_on_version_occurrence_resource"
    add_index :capacity_pair_definitions,
      [ :supplier_arrangement_version_id, :arrangement_item_id, :service_occurrence_id, :supplier_resource_id ],
      name: "index_capacity_pairs_on_item_coverage"
  end

  def create_capacity_pools
    create_table :capacity_pools, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_stable_owner_columns(table)
      table.uuid :supplying_supplier_id, null: false
      table.string :inventory_mode, null: false
      table.string :measurement_basis, null: false
      table.string :effective_time_zone, null: false
      table.timestamps null: false
    end

    add_pool_indexes
    add_arrangement_fk(:capacity_pools)
    add_item_fk(:capacity_pools)
    add_occurrence_fk(:capacity_pools)
    add_resource_fk(:capacity_pools)
    add_supplier_fk(:capacity_pools, :supplying_supplier_id, "capacity_pools_supplier_fk")
    add_check_constraint :capacity_pools,
      "inventory_mode IN (#{quoted_values(INVENTORY_MODES)})",
      name: "capacity_pools_inventory_mode"
    add_check_constraint :capacity_pools,
      "measurement_basis IN (#{quoted_values(MEASUREMENT_BASES)})",
      name: "capacity_pools_measurement_basis"
    add_check_constraint :capacity_pools,
      "btrim(effective_time_zone) <> ''",
      name: "capacity_pools_effective_time_zone"
  end

  def add_pool_indexes
    add_index :capacity_pools, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_pools_on_id_and_agency_id"
    add_index :capacity_pools, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_capacity_pools_on_id_departure_agency"
    add_index :capacity_pools,
      [
        :id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      unique: true,
      name: "index_capacity_pools_on_full_owner"
    add_index :capacity_pools,
      [ :agency_id, :supplying_supplier_id, :id ],
      name: "index_capacity_pools_on_supplier_dependency"
    add_index :capacity_pools,
      [ :supplier_arrangement_id, :arrangement_item_id, :service_occurrence_id, :supplier_resource_id ],
      name: "index_capacity_pools_on_pair_lookup"
  end

  def create_capacity_pool_definitions
    create_table :capacity_pool_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_version_owner_columns(table)
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.uuid :capacity_pair_definition_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.string :label, null: false, limit: 120
      table.string :normalized_label, null: false, limit: 120
      table.string :notes, limit: 2000
      table.string :unit_label, null: false, limit: 40
      table.bigint :proposed_opening_quantity
      table.string :evidence_kind
      table.date :evidence_on
      table.string :evidence_reference_note, limit: 500
      table.string :evidence_external_reference, limit: 160
      table.boolean :override, null: false, default: false
      table.string :override_reason, limit: 500
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_pool_definition_indexes
    add_version_fk(:capacity_pool_definitions)
    add_pair_fk(:capacity_pool_definitions)
    add_pool_fk(:capacity_pool_definitions)
    add_pool_definition_checks
  end

  def add_pool_definition_indexes
    add_index :capacity_pool_definitions, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_pool_defs_on_id_and_agency_id"
    add_index :capacity_pool_definitions, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_capacity_pool_defs_on_id_departure_agency"
    add_index :capacity_pool_definitions,
      [ :capacity_pool_id, :supplier_arrangement_version_id ],
      unique: true,
      name: "index_capacity_pool_defs_on_pool_and_version"
    add_index :capacity_pool_definitions,
      [ :supplier_arrangement_version_id, :capacity_pair_definition_id, :normalized_label ],
      unique: true,
      name: "index_capacity_pool_defs_on_unique_label"
    add_index :capacity_pool_definitions,
      [ :supplier_arrangement_version_id, :capacity_pair_definition_id, :position ],
      name: "index_capacity_pool_defs_on_position_lookup"

    execute <<~SQL
      ALTER TABLE capacity_pool_definitions
        ADD CONSTRAINT capacity_pool_defs_position_unique
        UNIQUE (supplier_arrangement_version_id, capacity_pair_definition_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL
  end

  def add_pool_definition_checks
    add_check_constraint :capacity_pool_definitions,
      "btrim(label) <> '' AND char_length(label) <= 120",
      name: "capacity_pool_defs_label"
    add_check_constraint :capacity_pool_definitions,
      "btrim(normalized_label) <> '' AND normalized_label = lower(btrim(label)) AND char_length(normalized_label) <= 120",
      name: "capacity_pool_defs_normalized_label"
    add_check_constraint :capacity_pool_definitions,
      "notes IS NULL OR (btrim(notes) <> '' AND char_length(notes) <= 2000)",
      name: "capacity_pool_defs_notes"
    add_check_constraint :capacity_pool_definitions,
      "btrim(unit_label) <> '' AND char_length(unit_label) <= 40",
      name: "capacity_pool_defs_unit_label"
    add_check_constraint :capacity_pool_definitions,
      "proposed_opening_quantity IS NULL OR proposed_opening_quantity > 0",
      name: "capacity_pool_defs_proposed_qty"
    add_check_constraint :capacity_pool_definitions,
      evidence_authority_check(allow_none: true),
      name: "capacity_pool_defs_evidence_xor_override"
    add_check_constraint :capacity_pool_definitions,
      "position > 0",
      name: "capacity_pool_defs_position_positive"
    add_check_constraint :capacity_pool_definitions,
      "lock_version >= 0",
      name: "capacity_pool_defs_lock_version"
  end

  def create_capacity_events
    create_table :capacity_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_version_owner_columns(table)
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.uuid :supplying_supplier_id, null: false
      table.string :event_type, null: false
      table.bigint :quantity, null: false
      table.string :measurement_basis, null: false
      table.date :effective_on, null: false
      table.string :effective_time_zone, null: false
      table.timestamptz :applies_at, null: false
      table.integer :effective_sequence, null: false
      table.timestamptz :recorded_at, null: false
      table.string :evidence_kind
      table.date :evidence_on
      table.string :evidence_reference_note, limit: 500
      table.string :evidence_external_reference, limit: 160
      table.boolean :override, null: false, default: false
      table.string :override_reason, limit: 500
      table.uuid :reinstates_event_id
      table.uuid :corrects_event_id
      table.uuid :capacity_reconciliation_id
      table.uuid :actor_id, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end

    add_event_indexes
    add_version_fk(:capacity_events)
    add_pool_fk(:capacity_events)
    add_supplier_fk(:capacity_events, :supplying_supplier_id, "capacity_events_supplier_fk")
    add_actor_fk(:capacity_events)
    add_idempotency_fk(:capacity_events)
    add_same_pool_event_fk(:reinstates_event_id, "capacity_events_reinstates_event_fk")
    add_same_pool_event_fk(:corrects_event_id, "capacity_events_corrects_event_fk")
    add_event_checks
  end

  def add_event_indexes
    add_index :capacity_events, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_events_on_id_and_agency_id"
    add_index :capacity_events, [ :id, :capacity_pool_id, :agency_id ],
      unique: true,
      name: "index_capacity_events_on_id_pool_agency"
    add_index :capacity_events, [ :capacity_pool_id ],
      unique: true,
      where: "event_type = 'established'",
      name: "index_capacity_events_one_established_per_pool"
    add_index :capacity_events,
      [ :capacity_pool_id, :effective_on, :effective_sequence ],
      unique: true,
      name: "index_capacity_events_on_pool_date_sequence"
    add_index :capacity_events,
      [ :capacity_pool_id, :effective_on, :effective_sequence, :recorded_at, :id ],
      name: "index_capacity_events_on_business_replay_order"
    add_index :capacity_events,
      [ :capacity_pool_id, :applies_at, :effective_on, :effective_sequence ],
      name: "index_capacity_events_on_applicability"
    add_index :capacity_events, [ :applies_at, :capacity_pool_id ],
      name: "index_capacity_events_on_applies_at"
    add_index :capacity_events, :agency_command_idempotency_key_id,
      unique: true,
      where: "agency_command_idempotency_key_id IS NOT NULL",
      name: "index_capacity_events_on_idempotency_key"
  end

  def add_event_checks
    add_check_constraint :capacity_events,
      "event_type IN (#{quoted_values(EVENT_TYPES)})",
      name: "capacity_events_type"
    add_check_constraint :capacity_events,
      "quantity > 0",
      name: "capacity_events_quantity_positive"
    add_check_constraint :capacity_events,
      "measurement_basis IN (#{quoted_values(MEASUREMENT_BASES)})",
      name: "capacity_events_measurement_basis"
    add_check_constraint :capacity_events,
      "btrim(effective_time_zone) <> ''",
      name: "capacity_events_effective_time_zone"
    add_check_constraint :capacity_events,
      "effective_sequence > 0",
      name: "capacity_events_sequence_positive"
    add_check_constraint :capacity_events,
      evidence_authority_check(allow_none: false),
      name: "capacity_events_evidence_xor_override"
    add_check_constraint :capacity_events,
      "((event_type = 'reinstated') = (reinstates_event_id IS NOT NULL))",
      name: "capacity_events_reinstates_pair"
    add_check_constraint :capacity_events,
      "((event_type IN ('corrected_up', 'corrected_down')) OR (corrects_event_id IS NULL AND capacity_reconciliation_id IS NULL))",
      name: "capacity_events_correction_sources_only"
    add_check_constraint :capacity_events,
      "(event_type NOT IN ('corrected_up', 'corrected_down')) OR ((corrects_event_id IS NOT NULL) <> (capacity_reconciliation_id IS NOT NULL))",
      name: "capacity_events_correction_source_xor"
  end

  def create_capacity_projections
    create_table :capacity_projections, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_stable_owner_columns(table)
      table.uuid :capacity_pool_id, null: false
      table.bigint :current_supplier_capacity, null: false, default: 0
      table.uuid :last_event_id
      table.date :last_effective_on
      table.integer :last_effective_sequence
      table.timestamptz :last_recorded_at
      table.timestamptz :next_applies_at
      table.uuid :next_event_id
      table.timestamptz :rebuilt_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_projection_indexes
    add_pool_fk(:capacity_projections)
    add_same_pool_event_fk(:last_event_id, "capacity_projections_last_event_fk", table_name: :capacity_projections)
    add_same_pool_event_fk(:next_event_id, "capacity_projections_next_event_fk", table_name: :capacity_projections)
    add_check_constraint :capacity_projections,
      "current_supplier_capacity >= 0",
      name: "capacity_projections_current_nonnegative"
    add_check_constraint :capacity_projections,
      "lock_version >= 0",
      name: "capacity_projections_lock_version"
  end

  def add_projection_indexes
    add_index :capacity_projections, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_projections_on_id_and_agency_id"
    add_index :capacity_projections, [ :capacity_pool_id ],
      unique: true,
      name: "index_capacity_projections_on_pool"
    add_index :capacity_projections, [ :next_applies_at, :capacity_pool_id ],
      where: "next_applies_at IS NOT NULL",
      name: "index_capacity_projections_on_next_applies_at"
  end

  def create_capacity_reconciliations
    create_table :capacity_reconciliations, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_version_owner_columns(table)
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.bigint :observed_quantity, null: false
      table.timestamptz :observed_at, null: false
      table.string :observed_time_zone, null: false
      table.bigint :ledger_quantity, null: false
      table.bigint :variance, null: false
      table.string :evidence_kind
      table.date :evidence_on
      table.string :evidence_reference_note, limit: 500
      table.string :evidence_external_reference, limit: 160
      table.boolean :override, null: false, default: false
      table.string :override_reason, limit: 500
      table.uuid :actor_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end

    add_reconciliation_indexes
    add_version_fk(:capacity_reconciliations)
    add_pool_fk(:capacity_reconciliations)
    add_actor_fk(:capacity_reconciliations)
    add_idempotency_fk(:capacity_reconciliations)
    add_reconciliation_checks
  end

  def add_reconciliation_indexes
    add_index :capacity_reconciliations, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_reconciliations_on_id_and_agency_id"
    add_index :capacity_reconciliations, [ :id, :capacity_pool_id, :agency_id ],
      unique: true,
      name: "index_capacity_reconciliations_on_id_pool_agency"
    add_index :capacity_reconciliations,
      [ :capacity_pool_id, :observed_at, :id ],
      name: "index_capacity_reconciliations_on_pool_observed"
    add_index :capacity_reconciliations,
      [ :capacity_pool_id, :id ],
      where: "variance <> 0",
      name: "index_capacity_reconciliations_on_discrepancy"
    add_index :capacity_reconciliations, :agency_command_idempotency_key_id,
      unique: true,
      where: "agency_command_idempotency_key_id IS NOT NULL",
      name: "index_capacity_reconciliations_on_idempotency_key"
  end

  def add_reconciliation_checks
    add_check_constraint :capacity_reconciliations,
      "observed_quantity >= 0",
      name: "capacity_reconciliations_observed_nonnegative"
    add_check_constraint :capacity_reconciliations,
      "ledger_quantity >= 0",
      name: "capacity_reconciliations_ledger_nonnegative"
    add_check_constraint :capacity_reconciliations,
      "variance = observed_quantity - ledger_quantity",
      name: "capacity_reconciliations_variance"
    add_check_constraint :capacity_reconciliations,
      "btrim(observed_time_zone) <> ''",
      name: "capacity_reconciliations_observed_time_zone"
    add_check_constraint :capacity_reconciliations,
      evidence_authority_check(allow_none: false),
      name: "capacity_reconciliations_evidence_xor_override"
  end

  def create_capacity_reconciliation_resolutions
    create_table :capacity_reconciliation_resolutions, id: :uuid, default: -> { "uuidv7()" } do |table|
      add_capacity_version_owner_columns(table)
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.uuid :capacity_pool_id, null: false
      table.uuid :capacity_reconciliation_id, null: false
      table.uuid :capacity_event_id, null: false
      table.uuid :actor_id, null: false
      table.timestamptz :resolved_at, null: false
      table.string :note, null: false, limit: 500
      table.timestamps null: false
    end

    add_index :capacity_reconciliation_resolutions, [ :id, :agency_id ],
      unique: true,
      name: "index_capacity_recon_resolutions_on_id_and_agency_id"
    add_index :capacity_reconciliation_resolutions,
      [ :capacity_reconciliation_id, :capacity_event_id ],
      unique: true,
      name: "index_capacity_recon_resolutions_on_recon_event"
    add_index :capacity_reconciliation_resolutions,
      [ :capacity_pool_id, :capacity_reconciliation_id, :resolved_at, :id ],
      name: "index_capacity_recon_resolutions_on_history"

    add_version_fk(:capacity_reconciliation_resolutions)
    add_pool_fk(:capacity_reconciliation_resolutions)
    add_same_pool_reconciliation_fk(:capacity_reconciliation_id, "capacity_recon_resolutions_reconciliation_fk", table_name: :capacity_reconciliation_resolutions)
    add_same_pool_event_fk(:capacity_event_id, "capacity_recon_resolutions_event_fk", table_name: :capacity_reconciliation_resolutions)
    add_actor_fk(:capacity_reconciliation_resolutions)
    add_check_constraint :capacity_reconciliation_resolutions,
      "btrim(note) <> '' AND char_length(note) <= 500",
      name: "capacity_recon_resolutions_note"
  end

  def add_capacity_event_reconciliation_fk
    add_same_pool_reconciliation_fk(:capacity_reconciliation_id, "capacity_events_reconciliation_fk", table_name: :capacity_events)
  end

  def create_capacity_triggers
    execute <<~SQL
      CREATE FUNCTION reject_capacity_pair_for_cancelled_occurrence() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM service_occurrences
          WHERE id = NEW.service_occurrence_id
            AND agency_id = NEW.agency_id
            AND status = 'cancelled'
        ) THEN
          RAISE EXCEPTION 'capacity pair cannot be created for a cancelled occurrence';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_pairs_reject_cancelled_occurrence
      BEFORE INSERT OR UPDATE OF service_occurrence_id ON capacity_pair_definitions
      FOR EACH ROW EXECUTE FUNCTION reject_capacity_pair_for_cancelled_occurrence();

      CREATE FUNCTION reject_invalid_capacity_pool_zone() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM pg_timezone_names
          WHERE name = NEW.effective_time_zone
        ) THEN
          RAISE EXCEPTION 'capacity pool effective_time_zone is not a recognized IANA timezone';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_pools_reject_invalid_zone
      BEFORE INSERT OR UPDATE OF effective_time_zone ON capacity_pools
      FOR EACH ROW EXECUTE FUNCTION reject_invalid_capacity_pool_zone();
    SQL

    create_reject_change_trigger(
      :capacity_pair_definitions,
      "capacity pair definition owner is immutable",
      %i[
        agency_id
        departure_id
        supplier_arrangement_id
        supplier_arrangement_version_id
        arrangement_item_id
        service_occurrence_id
        supplier_resource_id
      ]
    )
    create_reject_change_trigger(
      :capacity_pools,
      "capacity pool semantic identity is immutable",
      %i[
        agency_id
        departure_id
        supplier_arrangement_id
        arrangement_item_id
        service_occurrence_id
        supplier_resource_id
        supplying_supplier_id
        inventory_mode
        measurement_basis
        effective_time_zone
      ]
    )
    create_reject_change_trigger(
      :capacity_pool_definitions,
      "capacity pool definition owner is immutable",
      %i[
        agency_id
        departure_id
        supplier_arrangement_id
        supplier_arrangement_version_id
        arrangement_item_id
        service_occurrence_id
        supplier_resource_id
        capacity_pair_definition_id
        capacity_pool_id
      ]
    )
    create_reject_mutation_trigger(:capacity_events, "capacity event is append-only")
    create_reject_change_trigger(
      :capacity_projections,
      "capacity projection owner is immutable",
      %i[
        agency_id
        departure_id
        supplier_arrangement_id
        arrangement_item_id
        service_occurrence_id
        supplier_resource_id
        capacity_pool_id
      ]
    )
    create_reject_mutation_trigger(:capacity_reconciliations, "capacity reconciliation is append-only")
    create_reject_mutation_trigger(:capacity_reconciliation_resolutions, "capacity reconciliation resolution is append-only")
  end

  def add_capacity_stable_owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :arrangement_item_id, null: false
    table.uuid :service_occurrence_id, null: false
    table.uuid :supplier_resource_id, null: false
  end

  def add_capacity_version_owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
    table.uuid :arrangement_item_id, null: false
  end

  def add_arrangement_fk(table_name)
    add_foreign_key table_name, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "#{table_name}_arrangement_fk"
  end

  def add_item_fk(table_name)
    add_foreign_key table_name, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table_name}_item_fk"
  end

  def add_occurrence_fk(table_name)
    add_foreign_key table_name, :service_occurrences,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table_name}_occurrence_fk"
  end

  def add_resource_fk(table_name)
    add_foreign_key table_name, :supplier_resources,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table_name}_resource_fk"
  end

  def add_version_fk(table_name)
    add_foreign_key table_name, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table_name}_version_fk"
  end

  def add_item_definition_fk(table_name)
    add_foreign_key table_name, :arrangement_item_definitions,
      column: [
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      primary_key: [
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      name: "#{table_name}_item_definition_fk"
  end

  def add_occurrence_definition_fk(table_name)
    add_foreign_key table_name, :service_occurrence_definitions,
      column: [
        :service_occurrence_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      primary_key: [
        :service_occurrence_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      name: "#{table_name}_occurrence_definition_fk"
  end

  def add_resource_definition_fk(table_name)
    add_foreign_key table_name, :supplier_resource_definitions,
      column: [
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      primary_key: [
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      name: "#{table_name}_resource_definition_fk"
  end

  def add_pair_fk(table_name)
    add_foreign_key table_name, :capacity_pair_definitions,
      column: [
        :capacity_pair_definition_id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      primary_key: [
        :id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_version_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      name: "#{table_name}_pair_fk"
  end

  def add_pool_fk(table_name)
    add_foreign_key table_name, :capacity_pools,
      column: [
        :capacity_pool_id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      primary_key: [
        :id,
        :service_occurrence_id,
        :supplier_resource_id,
        :arrangement_item_id,
        :supplier_arrangement_id,
        :departure_id,
        :agency_id
      ],
      name: "#{table_name}_pool_fk"
  end

  def add_same_pool_event_fk(column, name, table_name: :capacity_events)
    add_foreign_key table_name, :capacity_events,
      column: [ column, :capacity_pool_id, :agency_id ],
      primary_key: [ :id, :capacity_pool_id, :agency_id ],
      name: name
  end

  def add_same_pool_reconciliation_fk(column, name, table_name:)
    add_foreign_key table_name, :capacity_reconciliations,
      column: [ column, :capacity_pool_id, :agency_id ],
      primary_key: [ :id, :capacity_pool_id, :agency_id ],
      name: name
  end

  def add_supplier_fk(table_name, column, name)
    add_foreign_key table_name, :suppliers,
      column: [ column, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: name
  end

  def add_actor_fk(table_name)
    add_foreign_key table_name, :agency_users,
      column: [ :actor_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{table_name}_actor_fk"
  end

  def add_idempotency_fk(table_name)
    add_foreign_key table_name, :agency_command_idempotency_keys,
      column: [ :agency_command_idempotency_key_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{table_name}_idempotency_fk"
  end

  def evidence_authority_check(allow_none:)
    ordinary_complete = <<~SQL.squish
      override = FALSE
      AND override_reason IS NULL
      AND evidence_kind IN (#{quoted_values(EVIDENCE_KINDS)})
      AND evidence_on IS NOT NULL
      AND evidence_reference_note IS NOT NULL
      AND btrim(evidence_reference_note) <> ''
      AND char_length(evidence_reference_note) <= 500
      AND (evidence_external_reference IS NULL OR (btrim(evidence_external_reference) <> '' AND char_length(evidence_external_reference) <= 160))
    SQL
    override_complete = <<~SQL.squish
      override = TRUE
      AND override_reason IS NOT NULL
      AND btrim(override_reason) <> ''
      AND char_length(override_reason) <= 500
      AND evidence_kind IS NULL
      AND evidence_on IS NULL
      AND evidence_reference_note IS NULL
      AND evidence_external_reference IS NULL
    SQL
    no_authority = <<~SQL.squish
      override = FALSE
      AND override_reason IS NULL
      AND evidence_kind IS NULL
      AND evidence_on IS NULL
      AND evidence_reference_note IS NULL
      AND evidence_external_reference IS NULL
    SQL

    checks = [ ordinary_complete, override_complete ]
    checks << no_authority if allow_none
    checks.map { |check| "(#{check})" }.join(" OR ")
  end

  def create_reject_change_trigger(table_name, message, columns)
    function_name = "reject_#{table_name.to_s.singularize}_owner_change"
    comparisons = columns.map do |column|
      "NEW.#{column} IS DISTINCT FROM OLD.#{column}"
    end.join("\n          OR ")

    execute <<~SQL
      CREATE FUNCTION #{function_name}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF #{comparisons} THEN
          RAISE EXCEPTION '#{message}';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER #{table_name}_reject_owner_change
      BEFORE UPDATE ON #{table_name}
      FOR EACH ROW EXECUTE FUNCTION #{function_name}();
    SQL
  end

  def create_reject_mutation_trigger(table_name, message)
    function_name = "reject_#{table_name.to_s.singularize}_mutation"

    execute <<~SQL
      CREATE FUNCTION #{function_name}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION '#{message}';
      END;
      $$;

      CREATE TRIGGER #{table_name}_reject_update
      BEFORE UPDATE ON #{table_name}
      FOR EACH ROW EXECUTE FUNCTION #{function_name}();

      CREATE TRIGGER #{table_name}_reject_delete
      BEFORE DELETE ON #{table_name}
      FOR EACH ROW EXECUTE FUNCTION #{function_name}();
    SQL
  end

  def quoted_values(values)
    values.map { |value| quote(value) }.join(", ")
  end
end
