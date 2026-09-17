class CreateSupplierCostPlanning < ActiveRecord::Migration[8.1]
  ECONOMIC_ROLES = %w[supplier_charge supplier_credit expected_commission informational_allocation].freeze
  CALCULATION_KINDS = %w[fixed unit_rate percentage minimum_amount_shortfall minimum_quantity_shortfall].freeze
  QUANTITY_BASES = %w[
    resource_units persons nights resource_nights person_nights occupancy_positions
    occupancy_position_nights single_occupancy_units single_occupancy_nights
  ].freeze

  def up
    add_departure_currency_key
    create_supplier_cost_sources
    create_supplier_cost_definitions
    create_supplier_cost_participant_categories
    create_supplier_cost_components
    create_supplier_cost_component_bases
    create_supplier_cost_usage_assumptions
    create_supplier_cost_occupancy_profiles
    create_supplier_cost_occupancy_profile_positions
    create_supplier_cost_triggers
  end

  def down
    drop_table :supplier_cost_occupancy_profile_positions
    drop_table :supplier_cost_occupancy_profiles
    drop_table :supplier_cost_usage_assumptions
    drop_table :supplier_cost_component_bases
    drop_table :supplier_cost_components
    drop_table :supplier_cost_participant_categories
    drop_table :supplier_cost_definitions
    drop_table :supplier_cost_sources
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_supplier_cost_source_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_component_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_component_basis_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_participant_category_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_usage_assumption_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_occupancy_profile_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_cost_occupancy_profile_position_owner_change();
      DROP FUNCTION IF EXISTS validate_supplier_cost_component();
      DROP FUNCTION IF EXISTS validate_supplier_cost_component_base();
      DROP FUNCTION IF EXISTS validate_supplier_cost_profile_position();
    SQL
    remove_index :departures, name: "index_departures_on_id_agency_currency"
  end

  private

  def add_departure_currency_key
    add_index :departures, [ :id, :agency_id, :operating_currency ],
      unique: true, name: "index_departures_on_id_agency_currency"
  end

  def create_supplier_cost_sources
    create_table :supplier_cost_sources, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :charging_supplier_id, null: false
      table.string :label, null: false, limit: 160
      table.string :notes, limit: 2_000
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_sources)
    add_index :supplier_cost_sources,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_sources_on_full_owner"
    add_index :supplier_cost_sources, [ :agency_id, :charging_supplier_id, :id ],
      name: "index_supplier_cost_sources_on_charging_supplier"
    add_index :supplier_cost_sources,
      [ :supplier_arrangement_version_id, :arrangement_item_id, :position ],
      name: "index_supplier_cost_sources_on_context_position"

    execute <<~SQL
      ALTER TABLE supplier_cost_sources
        ADD CONSTRAINT supplier_cost_sources_position_unique
        UNIQUE NULLS NOT DISTINCT
          (supplier_arrangement_version_id, arrangement_item_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL

    add_version_fk(:supplier_cost_sources)
    add_optional_exact_item_fks(:supplier_cost_sources)
    add_supplier_fk(:supplier_cost_sources, :charging_supplier_id, "supplier_cost_sources_charging_supplier_fk")
    add_check_constraint :supplier_cost_sources,
      "(arrangement_item_id IS NULL AND service_occurrence_id IS NULL AND supplier_resource_id IS NULL) OR arrangement_item_id IS NOT NULL",
      name: "supplier_cost_sources_context_shape"
    text_check(:supplier_cost_sources, :label, 160, required: true)
    text_check(:supplier_cost_sources, :notes, 2_000)
    positive_lock_and_position_checks(:supplier_cost_sources)
  end

  def create_supplier_cost_definitions
    create_table :supplier_cost_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_cost_source_id, null: false
      table.string :stage, null: false
      table.string :status, null: false, default: "working"
      table.string :mode, null: false, default: "calculated"
      table.string :currency, null: false, limit: 3
      table.string :rounding_mode, null: false, default: "half_up"
      table.string :zero_cost_reason, limit: 500
      table.uuid :forecast_ready_by_id
      table.timestamptz :forecast_ready_at
      table.string :readiness_provenance, limit: 500
      table.string :readiness_fingerprint, limit: 128
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_definitions)
    add_index :supplier_cost_definitions,
      [ :id, :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_definitions_on_full_owner"
    add_index :supplier_cost_definitions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_definitions_on_context_owner"
    add_index :supplier_cost_definitions, [ :supplier_cost_source_id, :stage ],
      unique: true, name: "index_supplier_cost_definitions_on_source_stage"
    add_source_fk(:supplier_cost_definitions)
    add_foreign_key :supplier_cost_definitions, :departures,
      column: [ :departure_id, :agency_id, :currency ],
      primary_key: [ :id, :agency_id, :operating_currency ],
      name: "supplier_cost_definitions_departure_currency_fk"
    add_foreign_key :supplier_cost_definitions, :agency_users,
      column: [ :forecast_ready_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_cost_definitions_ready_actor_fk"
    add_check_constraint :supplier_cost_definitions, "stage IN ('estimate', 'contracted')",
      name: "supplier_cost_definitions_stage"
    add_check_constraint :supplier_cost_definitions, "status IN ('working', 'forecast_ready')",
      name: "supplier_cost_definitions_status"
    add_check_constraint :supplier_cost_definitions, "mode IN ('calculated', 'zero_cost')",
      name: "supplier_cost_definitions_mode"
    add_check_constraint :supplier_cost_definitions, "currency ~ '^[A-Z]{3}$'",
      name: "supplier_cost_definitions_currency"
    add_check_constraint :supplier_cost_definitions, "rounding_mode = 'half_up'",
      name: "supplier_cost_definitions_rounding_mode"
    add_check_constraint :supplier_cost_definitions,
      "(mode = 'zero_cost') = (zero_cost_reason IS NOT NULL)",
      name: "supplier_cost_definitions_zero_reason_pair"
    text_check(:supplier_cost_definitions, :zero_cost_reason, 500)
    text_check(:supplier_cost_definitions, :readiness_provenance, 500)
    add_check_constraint :supplier_cost_definitions,
      <<~SQL.squish,
        (
          status = 'working'
          AND forecast_ready_by_id IS NULL
          AND forecast_ready_at IS NULL
          AND readiness_fingerprint IS NULL
          AND readiness_provenance IS NULL
        ) OR (
          status = 'forecast_ready'
          AND forecast_ready_by_id IS NOT NULL
          AND forecast_ready_at IS NOT NULL
          AND readiness_fingerprint IS NOT NULL
          AND btrim(readiness_fingerprint) <> ''
          AND char_length(readiness_fingerprint) <= 128
          AND (stage <> 'contracted' OR readiness_provenance IS NOT NULL)
        )
      SQL
      name: "supplier_cost_definitions_readiness_shape"
    add_check_constraint :supplier_cost_definitions, "lock_version >= 0",
      name: "supplier_cost_definitions_lock_version"
  end

  def create_supplier_cost_participant_categories
    create_table :supplier_cost_participant_categories, id: :uuid, default: -> { "uuidv7()" } do |table|
      item_owner_columns(table)
      table.string :label, null: false, limit: 80
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_participant_categories)
    add_index :supplier_cost_participant_categories,
      [ :id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_categories_on_full_owner"
    add_index :supplier_cost_participant_categories,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_categories_on_context_owner"
    execute <<~SQL
      ALTER TABLE supplier_cost_participant_categories
        ADD CONSTRAINT supplier_cost_categories_position_unique
        UNIQUE (supplier_arrangement_version_id, arrangement_item_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL
    add_version_fk(:supplier_cost_participant_categories)
    add_item_definition_fk(:supplier_cost_participant_categories)
    text_check(:supplier_cost_participant_categories, :label, 80, required: true)
    positive_lock_and_position_checks(:supplier_cost_participant_categories)
  end

  def create_supplier_cost_components
    create_table :supplier_cost_components, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_cost_definition_id, null: false
      table.string :label, null: false, limit: 160
      table.string :economic_role, null: false
      table.string :calculation_kind, null: false
      table.bigint :amount_minor_units
      table.decimal :rate, precision: 20, scale: 10
      table.bigint :minimum_minor_units
      table.bigint :minimum_quantity
      table.string :quantity_basis
      table.uuid :participant_category_id
      table.integer :occupancy_position_from
      table.integer :occupancy_position_to
      table.string :percentage_treatment
      table.boolean :pass_through, null: false, default: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_components)
    add_index :supplier_cost_components,
      [ :id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_components_on_full_owner"
    add_index :supplier_cost_components, [ :supplier_cost_definition_id, :position ],
      unique: true, name: "index_supplier_cost_components_on_definition_position"
    add_definition_fk(:supplier_cost_components)
    add_foreign_key :supplier_cost_components, :supplier_cost_participant_categories,
      column: [ :participant_category_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_cost_components_category_fk"
    text_check(:supplier_cost_components, :label, 160, required: true)
    add_check_constraint :supplier_cost_components,
      "economic_role IN (#{quoted(ECONOMIC_ROLES)})", name: "supplier_cost_components_economic_role"
    add_check_constraint :supplier_cost_components,
      "calculation_kind IN (#{quoted(CALCULATION_KINDS)})", name: "supplier_cost_components_calculation_kind"
    add_check_constraint :supplier_cost_components,
      "quantity_basis IS NULL OR quantity_basis IN (#{quoted(QUANTITY_BASES)})",
      name: "supplier_cost_components_quantity_basis"
    add_check_constraint :supplier_cost_components,
      "amount_minor_units IS NULL OR amount_minor_units >= 0", name: "supplier_cost_components_amount_nonnegative"
    add_check_constraint :supplier_cost_components,
      "minimum_minor_units IS NULL OR minimum_minor_units >= 0", name: "supplier_cost_components_minimum_nonnegative"
    add_check_constraint :supplier_cost_components,
      "rate IS NULL OR rate >= 0", name: "supplier_cost_components_rate_nonnegative"
    add_check_constraint :supplier_cost_components,
      "minimum_quantity IS NULL OR minimum_quantity > 0", name: "supplier_cost_components_minimum_quantity_positive"
    add_check_constraint :supplier_cost_components,
      "(occupancy_position_from IS NULL OR occupancy_position_from > 0) AND (occupancy_position_to IS NULL OR occupancy_position_to > 0) AND (occupancy_position_to IS NULL OR occupancy_position_from IS NOT NULL) AND (occupancy_position_to IS NULL OR occupancy_position_to >= occupancy_position_from)",
      name: "supplier_cost_components_position_selector"
    add_check_constraint :supplier_cost_components,
      "participant_category_id IS NULL OR quantity_basis IN ('persons', 'person_nights', 'occupancy_positions', 'occupancy_position_nights')",
      name: "supplier_cost_components_category_basis"
    add_check_constraint :supplier_cost_components,
      "occupancy_position_from IS NULL OR quantity_basis IN ('occupancy_positions', 'occupancy_position_nights')",
      name: "supplier_cost_components_occupancy_basis"
    add_check_constraint :supplier_cost_components,
      "NOT pass_through OR economic_role <> 'expected_commission'",
      name: "supplier_cost_components_pass_through_role"
    add_check_constraint :supplier_cost_components,
      component_shape_check, name: "supplier_cost_components_kind_shape"
    add_check_constraint :supplier_cost_components,
      "percentage_treatment <> 'included' OR economic_role = 'informational_allocation'",
      name: "supplier_cost_components_included_role"
    positive_lock_and_position_checks(:supplier_cost_components)
  end

  def create_supplier_cost_component_bases
    create_table :supplier_cost_component_bases, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_cost_definition_id, null: false
      table.uuid :supplier_cost_component_id, null: false
      table.uuid :base_component_id, null: false
      table.string :direction, null: false
      table.integer :position, null: false
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_component_bases)
    add_index :supplier_cost_component_bases,
      [ :supplier_cost_component_id, :base_component_id ],
      unique: true, name: "index_supplier_cost_component_bases_on_pair"
    add_index :supplier_cost_component_bases, [ :supplier_cost_component_id, :position ],
      unique: true, name: "index_supplier_cost_component_bases_on_position"
    add_index :supplier_cost_component_bases, :base_component_id,
      name: "index_supplier_cost_component_bases_on_base"
    add_definition_fk(:supplier_cost_component_bases)
    add_component_fk(:supplier_cost_component_bases, :supplier_cost_component_id, "supplier_cost_component_bases_component_fk")
    add_component_fk(:supplier_cost_component_bases, :base_component_id, "supplier_cost_component_bases_base_fk")
    add_check_constraint :supplier_cost_component_bases, "direction IN ('add', 'subtract')",
      name: "supplier_cost_component_bases_direction"
    add_check_constraint :supplier_cost_component_bases, "position > 0",
      name: "supplier_cost_component_bases_position_positive"
  end

  def create_supplier_cost_usage_assumptions
    create_table :supplier_cost_usage_assumptions, id: :uuid, default: -> { "uuidv7()" } do |table|
      item_owner_columns(table)
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.bigint :expected_resource_units
      table.bigint :expected_persons
      table.bigint :expected_billable_nights
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_usage_assumptions)
    add_index :supplier_cost_usage_assumptions,
      [ :id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_assumptions_on_full_owner"
    execute <<~SQL
      CREATE UNIQUE INDEX index_supplier_cost_assumptions_on_context
        ON supplier_cost_usage_assumptions
        (supplier_arrangement_version_id, arrangement_item_id, service_occurrence_id, supplier_resource_id)
        NULLS NOT DISTINCT;
    SQL
    add_version_fk(:supplier_cost_usage_assumptions)
    add_item_definition_fk(:supplier_cost_usage_assumptions)
    add_optional_occurrence_definition_fk(:supplier_cost_usage_assumptions)
    add_optional_resource_definition_fk(:supplier_cost_usage_assumptions)
    add_check_constraint :supplier_cost_usage_assumptions,
      "(expected_resource_units IS NULL OR expected_resource_units >= 0) AND (expected_persons IS NULL OR expected_persons >= 0) AND (expected_billable_nights IS NULL OR expected_billable_nights >= 0)",
      name: "supplier_cost_assumptions_quantities_nonnegative"
    add_check_constraint :supplier_cost_usage_assumptions, "lock_version >= 0",
      name: "supplier_cost_assumptions_lock_version"
  end

  def create_supplier_cost_occupancy_profiles
    create_table :supplier_cost_occupancy_profiles, id: :uuid, default: -> { "uuidv7()" } do |table|
      item_owner_columns(table)
      table.uuid :supplier_cost_usage_assumption_id, null: false
      table.string :label, null: false, limit: 120
      table.bigint :resource_unit_count, null: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_occupancy_profiles)
    add_index :supplier_cost_occupancy_profiles,
      [ :id, :supplier_cost_usage_assumption_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_cost_profiles_on_full_owner"
    execute <<~SQL
      ALTER TABLE supplier_cost_occupancy_profiles
        ADD CONSTRAINT supplier_cost_profiles_position_unique
        UNIQUE (supplier_cost_usage_assumption_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL
    add_assumption_fk(:supplier_cost_occupancy_profiles)
    text_check(:supplier_cost_occupancy_profiles, :label, 120, required: true)
    add_check_constraint :supplier_cost_occupancy_profiles, "resource_unit_count > 0",
      name: "supplier_cost_profiles_unit_count_positive"
    positive_lock_and_position_checks(:supplier_cost_occupancy_profiles)
  end

  def create_supplier_cost_occupancy_profile_positions
    create_table :supplier_cost_occupancy_profile_positions, id: :uuid, default: -> { "uuidv7()" } do |table|
      item_owner_columns(table)
      table.uuid :supplier_cost_usage_assumption_id, null: false
      table.uuid :supplier_cost_occupancy_profile_id, null: false
      table.uuid :participant_category_id, null: false
      table.integer :occupancy_position, null: false
      table.timestamps null: false
    end

    identity_indexes(:supplier_cost_occupancy_profile_positions)
    add_index :supplier_cost_occupancy_profile_positions,
      [ :supplier_cost_occupancy_profile_id, :occupancy_position ],
      unique: true, name: "index_supplier_cost_profile_positions_on_position"
    add_profile_fk(:supplier_cost_occupancy_profile_positions)
    add_foreign_key :supplier_cost_occupancy_profile_positions, :supplier_cost_participant_categories,
      column: [ :participant_category_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_cost_profile_positions_category_fk"
    add_check_constraint :supplier_cost_occupancy_profile_positions, "occupancy_position > 0",
      name: "supplier_cost_profile_positions_positive"
  end

  def create_supplier_cost_triggers
    immutable = {
      supplier_cost_sources: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id service_occurrence_id supplier_resource_id charging_supplier_id],
      supplier_cost_definitions: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id supplier_cost_source_id],
      supplier_cost_components: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id supplier_cost_definition_id],
      supplier_cost_component_bases: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id supplier_cost_definition_id supplier_cost_component_id base_component_id],
      supplier_cost_participant_categories: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id],
      supplier_cost_usage_assumptions: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id service_occurrence_id supplier_resource_id],
      supplier_cost_occupancy_profiles: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id supplier_cost_usage_assumption_id],
      supplier_cost_occupancy_profile_positions: %i[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id supplier_cost_usage_assumption_id supplier_cost_occupancy_profile_id participant_category_id occupancy_position]
    }
    immutable.each { |table, columns| create_owner_trigger(table, columns) }

    execute <<~SQL
      CREATE FUNCTION validate_supplier_cost_component() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE source_item uuid;
      DECLARE definition_mode text;
      BEGIN
        SELECT s.arrangement_item_id, d.mode INTO source_item, definition_mode
          FROM supplier_cost_definitions d
          JOIN supplier_cost_sources s ON s.id = d.supplier_cost_source_id
         WHERE d.id = NEW.supplier_cost_definition_id;
        IF definition_mode <> 'calculated' THEN
          RAISE EXCEPTION 'zero-cost definitions cannot contain components';
        END IF;
        IF source_item IS NULL AND
           (NEW.quantity_basis IS NOT NULL OR NEW.participant_category_id IS NOT NULL
            OR NEW.occupancy_position_from IS NOT NULL OR NEW.calculation_kind = 'minimum_quantity_shortfall') THEN
          RAISE EXCEPTION 'arrangement-wide cost components cannot use quantity inputs';
        END IF;
        IF NEW.participant_category_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM supplier_cost_participant_categories c
           WHERE c.id = NEW.participant_category_id AND c.arrangement_item_id = source_item
        ) THEN
          RAISE EXCEPTION 'cost component participant category must match source item';
        END IF;
        IF TG_OP = 'UPDATE' AND NEW.position IS DISTINCT FROM OLD.position AND (
          EXISTS (
            SELECT 1
              FROM supplier_cost_component_bases l
              JOIN supplier_cost_components b ON b.id = l.base_component_id
             WHERE l.supplier_cost_component_id = NEW.id
               AND b.position >= NEW.position
          ) OR EXISTS (
            SELECT 1
              FROM supplier_cost_component_bases l
              JOIN supplier_cost_components c ON c.id = l.supplier_cost_component_id
             WHERE l.base_component_id = NEW.id
               AND c.position <= NEW.position
          )
        ) THEN
          RAISE EXCEPTION 'cost component reorder would create a forward base';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER supplier_cost_components_validate_context
        BEFORE INSERT OR UPDATE ON supplier_cost_components
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_cost_component();

      CREATE FUNCTION validate_supplier_cost_component_base() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE component_position integer;
      DECLARE component_kind text;
      DECLARE base_position integer;
      DECLARE base_kind text;
      BEGIN
        SELECT position, calculation_kind INTO component_position, component_kind
          FROM supplier_cost_components
         WHERE id = NEW.supplier_cost_component_id
           AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
        SELECT position, calculation_kind INTO base_position, base_kind
          FROM supplier_cost_components
         WHERE id = NEW.base_component_id
           AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
        IF component_position IS NULL OR base_position IS NULL OR base_position >= component_position THEN
          RAISE EXCEPTION 'cost component base must be an earlier component in the same definition';
        END IF;
        IF component_kind NOT IN ('percentage', 'minimum_amount_shortfall', 'minimum_quantity_shortfall') THEN
          RAISE EXCEPTION 'cost component kind does not accept bases';
        END IF;
        IF component_kind = 'minimum_quantity_shortfall' AND
           (base_kind <> 'unit_rate' OR NEW.direction <> 'add') THEN
          RAISE EXCEPTION 'quantity minimum base must be one earlier unit rate';
        END IF;
        IF component_kind = 'minimum_quantity_shortfall' AND EXISTS (
          SELECT 1 FROM supplier_cost_component_bases
           WHERE supplier_cost_component_id = NEW.supplier_cost_component_id
             AND id <> NEW.id
        ) THEN
          RAISE EXCEPTION 'quantity minimum accepts exactly one base';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER supplier_cost_component_bases_validate
        BEFORE INSERT OR UPDATE ON supplier_cost_component_bases
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_cost_component_base();
    SQL
  end

  def owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
  end

  def item_owner_columns(table)
    owner_columns(table)
    table.uuid :arrangement_item_id, null: false
  end

  def identity_indexes(table)
    prefix = {
      supplier_cost_participant_categories: "supplier_cost_categories",
      supplier_cost_usage_assumptions: "supplier_cost_assumptions",
      supplier_cost_occupancy_profiles: "supplier_cost_profiles",
      supplier_cost_occupancy_profile_positions: "supplier_cost_profile_positions"
    }.fetch(table, table.to_s)
    add_index table, [ :id, :agency_id ], unique: true, name: "index_#{prefix}_on_id_and_agency_id"
    add_index table, [ :id, :departure_id, :agency_id ], unique: true,
      name: "index_#{prefix}_on_id_departure_agency"
  end

  def add_version_fk(table)
    add_foreign_key table, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_version_fk"
  end

  def add_optional_exact_item_fks(table)
    add_foreign_key table, :arrangement_item_definitions,
      column: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_item_definition_fk"
    add_optional_occurrence_definition_fk(table)
    add_optional_resource_definition_fk(table)
  end

  def add_item_definition_fk(table)
    add_foreign_key table, :arrangement_item_definitions,
      column: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_item_definition_fk"
  end

  def add_optional_occurrence_definition_fk(table)
    add_foreign_key table, :service_occurrence_definitions,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_occurrence_definition_fk"
  end

  def add_optional_resource_definition_fk(table)
    add_foreign_key table, :supplier_resource_definitions,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_resource_definition_fk"
  end

  def add_supplier_fk(table, column, name)
    add_foreign_key table, :suppliers, column: [ column, :agency_id ],
      primary_key: [ :id, :agency_id ], name: name
  end

  def add_source_fk(table)
    add_foreign_key table, :supplier_cost_sources,
      column: [ :supplier_cost_source_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_source_fk"
  end

  def add_definition_fk(table)
    add_foreign_key table, :supplier_cost_definitions,
      column: [ :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_definition_fk"
  end

  def add_component_fk(table, column, name)
    add_foreign_key table, :supplier_cost_components,
      column: [ column, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: name
  end

  def add_assumption_fk(table)
    add_foreign_key table, :supplier_cost_usage_assumptions,
      column: [ :supplier_cost_usage_assumption_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_assumption_fk"
  end

  def add_profile_fk(table)
    add_foreign_key table, :supplier_cost_occupancy_profiles,
      column: [ :supplier_cost_occupancy_profile_id, :supplier_cost_usage_assumption_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_cost_usage_assumption_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{table}_profile_fk"
  end

  def positive_lock_and_position_checks(table)
    add_check_constraint table, "position > 0", name: "#{table}_position_positive"
    add_check_constraint table, "lock_version >= 0", name: "#{table}_lock_version"
  end

  def text_check(table, column, limit, required: false)
    expression = "btrim(#{column}) <> '' AND char_length(#{column}) <= #{limit}"
    expression = "#{column} IS NULL OR (#{expression})" unless required
    add_check_constraint table, expression, name: "#{table}_#{column}"
  end

  def component_shape_check
    <<~SQL.squish
      (
        calculation_kind = 'fixed'
        AND amount_minor_units IS NOT NULL
        AND rate IS NULL AND minimum_minor_units IS NULL AND minimum_quantity IS NULL
        AND quantity_basis IS NULL AND participant_category_id IS NULL
        AND occupancy_position_from IS NULL AND occupancy_position_to IS NULL
        AND percentage_treatment IS NULL
      ) OR (
        calculation_kind = 'unit_rate'
        AND amount_minor_units IS NOT NULL AND quantity_basis IS NOT NULL
        AND rate IS NULL AND minimum_minor_units IS NULL AND minimum_quantity IS NULL
        AND percentage_treatment IS NULL
      ) OR (
        calculation_kind = 'percentage'
        AND rate IS NOT NULL AND percentage_treatment IN ('additive', 'included')
        AND amount_minor_units IS NULL AND minimum_minor_units IS NULL
        AND minimum_quantity IS NULL AND quantity_basis IS NULL
        AND participant_category_id IS NULL
        AND occupancy_position_from IS NULL AND occupancy_position_to IS NULL
      ) OR (
        calculation_kind = 'minimum_amount_shortfall'
        AND minimum_minor_units IS NOT NULL AND economic_role = 'supplier_charge'
        AND amount_minor_units IS NULL AND rate IS NULL AND minimum_quantity IS NULL
        AND quantity_basis IS NULL AND participant_category_id IS NULL
        AND occupancy_position_from IS NULL AND occupancy_position_to IS NULL
        AND percentage_treatment IS NULL
      ) OR (
        calculation_kind = 'minimum_quantity_shortfall'
        AND minimum_quantity IS NOT NULL AND quantity_basis IS NOT NULL
        AND economic_role = 'supplier_charge'
        AND amount_minor_units IS NULL AND rate IS NULL AND minimum_minor_units IS NULL
        AND percentage_treatment IS NULL
      )
    SQL
  end

  def create_owner_trigger(table, columns)
    function_name = "reject_#{table.to_s.singularize}_owner_change"
    comparisons = columns.map { |column| "NEW.#{column} IS DISTINCT FROM OLD.#{column}" }.join("\n          OR ")
    execute <<~SQL
      CREATE FUNCTION #{function_name}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF #{comparisons} THEN
          RAISE EXCEPTION '#{table.to_s.singularize} owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER #{table}_reject_owner_change
        BEFORE UPDATE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION #{function_name}();
    SQL
  end

  def quoted(values)
    values.map { |value| quote(value) }.join(", ")
  end
end
