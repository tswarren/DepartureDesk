class CreateSupplierArrangementStructure < ActiveRecord::Migration[8.1]
  ITEM_CATEGORIES = %w[
    cruise
    lodging
    air
    ground_transportation
    dining
    activity_attraction
    insurance
    other
  ].freeze

  def up
    add_supplier_contact_contracting_key
    create_idempotency_keys
    create_supplier_arrangements
    create_supplier_arrangement_versions
    create_arrangement_items
    create_service_occurrences
    create_supplier_resources
    create_arrangement_item_definitions
    create_service_occurrence_definitions
    create_supplier_resource_definitions
    create_immutable_owner_triggers
    create_time_zone_trigger
  end

  def down
    drop_table :supplier_resource_definitions
    drop_table :service_occurrence_definitions
    drop_table :arrangement_item_definitions
    drop_table :supplier_resources
    drop_table :service_occurrences
    drop_table :arrangement_items
    drop_table :supplier_arrangement_versions
    drop_table :supplier_arrangements
    drop_table :agency_command_idempotency_keys

    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_supplier_arrangement_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_arrangement_version_owner_change();
      DROP FUNCTION IF EXISTS reject_arrangement_item_owner_change();
      DROP FUNCTION IF EXISTS reject_service_occurrence_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_resource_owner_change();
      DROP FUNCTION IF EXISTS reject_arrangement_item_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_service_occurrence_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_resource_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_invalid_service_occurrence_definition_zone();
    SQL

    remove_index :supplier_contacts, name: "index_supplier_contacts_on_id_supplier_agency"
  end

  private

  def add_supplier_contact_contracting_key
    add_index :supplier_contacts, [ :id, :supplier_id, :agency_id ],
      unique: true,
      name: "index_supplier_contacts_on_id_supplier_agency"
  end

  def create_idempotency_keys
    create_table :agency_command_idempotency_keys, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :command_name, null: false, limit: 120
      table.string :idempotency_key, null: false, limit: 120
      table.string :payload_digest, null: false, limit: 128
      table.string :result_record_type, null: false, limit: 120
      table.uuid :result_record_id, null: false
      table.timestamps null: false
    end

    add_index :agency_command_idempotency_keys,
      [ :agency_id, :command_name, :idempotency_key ],
      unique: true,
      name: "index_command_idempotency_on_agency_command_key"
    add_check_constraint :agency_command_idempotency_keys,
      "btrim(command_name) <> '' AND char_length(command_name) <= 120",
      name: "agency_command_idempotency_keys_command_name"
    add_check_constraint :agency_command_idempotency_keys,
      "btrim(idempotency_key) <> '' AND char_length(idempotency_key) <= 120",
      name: "agency_command_idempotency_keys_key"
    add_check_constraint :agency_command_idempotency_keys,
      "btrim(payload_digest) <> '' AND char_length(payload_digest) <= 128",
      name: "agency_command_idempotency_keys_payload_digest"
    add_check_constraint :agency_command_idempotency_keys,
      "btrim(result_record_type) <> '' AND char_length(result_record_type) <= 120",
      name: "agency_command_idempotency_keys_result_type"
  end

  def create_supplier_arrangements
    create_table :supplier_arrangements, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :contracting_supplier_id, null: false
      table.uuid :supplier_contact_id
      table.string :name, null: false, limit: 160
      table.string :status, null: false, default: "draft"
      table.timestamptz :abandoned_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangements, [ :id, :agency_id ],
      unique: true,
      name: "index_supplier_arrangements_on_id_and_agency_id"
    add_index :supplier_arrangements, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_supplier_arrangements_on_id_departure_agency"
    add_index :supplier_arrangements, [ :agency_id, :departure_id, :status, :name, :id ],
      name: "index_supplier_arrangements_on_departure_list"
    add_index :supplier_arrangements, [ :agency_id, :contracting_supplier_id, :status, :id ],
      name: "index_supplier_arrangements_on_supplier_dependencies"

    add_foreign_key :supplier_arrangements, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_arrangements_departure_agency_fk"
    add_foreign_key :supplier_arrangements, :suppliers,
      column: [ :contracting_supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_arrangements_contracting_supplier_fk"
    add_foreign_key :supplier_arrangements, :supplier_contacts,
      column: [ :supplier_contact_id, :contracting_supplier_id, :agency_id ],
      primary_key: [ :id, :supplier_id, :agency_id ],
      name: "supplier_arrangements_contracting_contact_fk"

    add_check_constraint :supplier_arrangements,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "supplier_arrangements_name"
    add_check_constraint :supplier_arrangements,
      "status IN ('draft', 'active', 'ended', 'abandoned')",
      name: "supplier_arrangements_status"
    add_check_constraint :supplier_arrangements,
      "(status = 'abandoned') = (abandoned_at IS NOT NULL)",
      name: "supplier_arrangements_abandoned_at_pair"
    add_check_constraint :supplier_arrangements,
      "lock_version >= 0",
      name: "supplier_arrangements_lock_version"
  end

  def create_supplier_arrangement_versions
    create_table :supplier_arrangement_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.integer :version_number, null: false
      table.string :status, null: false, default: "draft"
      table.timestamptz :abandoned_at
      table.string :abandoned_reason, limit: 500
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangement_versions, [ :id, :agency_id ],
      unique: true,
      name: "index_supplier_arrangement_versions_on_id_and_agency"
    add_index :supplier_arrangement_versions, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_supplier_arrangement_versions_on_id_departure_agency"
    add_index :supplier_arrangement_versions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_supplier_arrangement_versions_on_full_owner"
    add_index :supplier_arrangement_versions, [ :supplier_arrangement_id, :version_number ],
      unique: true,
      name: "index_supplier_arrangement_versions_on_number"
    add_index :supplier_arrangement_versions, :supplier_arrangement_id,
      unique: true,
      where: "status = 'draft'",
      name: "index_supplier_arrangement_versions_one_draft"
    add_index :supplier_arrangement_versions, :supplier_arrangement_id,
      unique: true,
      where: "status = 'activated'",
      name: "index_supplier_arrangement_versions_one_activated"

    add_foreign_key :supplier_arrangement_versions, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "supplier_arrangement_versions_arrangement_fk"

    add_check_constraint :supplier_arrangement_versions,
      "version_number > 0",
      name: "supplier_arrangement_versions_number_positive"
    add_check_constraint :supplier_arrangement_versions,
      "status IN ('draft', 'activated', 'superseded', 'abandoned')",
      name: "supplier_arrangement_versions_status"
    add_check_constraint :supplier_arrangement_versions,
      "(status = 'abandoned') = (abandoned_at IS NOT NULL)",
      name: "supplier_arrangement_versions_abandoned_at_pair"
    add_check_constraint :supplier_arrangement_versions,
      "(status = 'abandoned') = (abandoned_reason IS NOT NULL)",
      name: "supplier_arrangement_versions_reason_pair"
    add_check_constraint :supplier_arrangement_versions,
      "abandoned_reason IS NULL OR (btrim(abandoned_reason) <> '' AND char_length(abandoned_reason) <= 500)",
      name: "supplier_arrangement_versions_reason"
    add_check_constraint :supplier_arrangement_versions,
      "lock_version >= 0",
      name: "supplier_arrangement_versions_lock_version"
  end

  def create_arrangement_items
    create_table :arrangement_items, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.timestamps null: false
    end

    add_identity_indexes(:arrangement_items, parent: :supplier_arrangement)
    add_arrangement_fk(:arrangement_items)
  end

  def create_service_occurrences
    create_table :service_occurrences, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.string :status, null: false, default: "planned"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_identity_indexes(:service_occurrences, parent: :arrangement_item)
    add_item_fk(:service_occurrences)
    add_check_constraint :service_occurrences,
      "status IN ('planned', 'cancelled')",
      name: "service_occurrences_status"
    add_check_constraint :service_occurrences,
      "lock_version >= 0",
      name: "service_occurrences_lock_version"
  end

  def create_supplier_resources
    create_table :supplier_resources, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.timestamps null: false
    end

    add_identity_indexes(:supplier_resources, parent: :arrangement_item)
    add_item_fk(:supplier_resources)
  end

  def create_arrangement_item_definitions
    create_table :arrangement_item_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.string :name, null: false, limit: 160
      table.string :description, limit: 2000
      table.string :category, null: false
      table.string :other_category_label, limit: 80
      table.uuid :default_service_provider_id
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_definition_indexes(:arrangement_item_definitions, stable: :arrangement_item)
    add_version_fk(:arrangement_item_definitions)
    add_item_fk(:arrangement_item_definitions)
    add_supplier_fk(:arrangement_item_definitions, :default_service_provider_id, "arrangement_item_definitions_provider_fk")
    add_check_constraint :arrangement_item_definitions,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "arrangement_item_definitions_name"
    add_check_constraint :arrangement_item_definitions,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 2000)",
      name: "arrangement_item_definitions_description"
    add_check_constraint :arrangement_item_definitions,
      "category IN (#{quoted_values(ITEM_CATEGORIES)})",
      name: "arrangement_item_definitions_category"
    add_check_constraint :arrangement_item_definitions,
      "((category = 'other') = (other_category_label IS NOT NULL)) AND (other_category_label IS NULL OR (btrim(other_category_label) <> '' AND char_length(other_category_label) <= 80))",
      name: "arrangement_item_definitions_other_label"
    add_check_constraint :arrangement_item_definitions,
      "position > 0",
      name: "arrangement_item_definitions_position_positive"
    add_check_constraint :arrangement_item_definitions,
      "lock_version >= 0",
      name: "arrangement_item_definitions_lock_version"

    execute <<~SQL
      ALTER TABLE arrangement_item_definitions
        ADD CONSTRAINT arrangement_item_definitions_position_unique
        UNIQUE (supplier_arrangement_version_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL
  end

  def create_service_occurrence_definitions
    create_table :service_occurrence_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.string :name, null: false, limit: 160
      table.string :description, limit: 2000
      table.date :starts_on, null: false
      table.date :ends_on, null: false
      table.time :starts_at_local
      table.time :ends_at_local
      table.string :time_zone, null: false
      table.uuid :service_provider_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_definition_indexes(:service_occurrence_definitions, stable: :service_occurrence)
    add_version_fk(:service_occurrence_definitions)
    add_occurrence_fk(:service_occurrence_definitions)
    add_supplier_fk(:service_occurrence_definitions, :service_provider_id, "service_occurrence_definitions_provider_fk")
    add_check_constraint :service_occurrence_definitions,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "service_occurrence_definitions_name"
    add_check_constraint :service_occurrence_definitions,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 2000)",
      name: "service_occurrence_definitions_description"
    add_check_constraint :service_occurrence_definitions,
      "starts_on <= ends_on",
      name: "service_occurrence_definitions_date_order"
    add_check_constraint :service_occurrence_definitions,
      "(starts_at_local IS NULL) = (ends_at_local IS NULL)",
      name: "service_occurrence_definitions_times_paired"
    add_check_constraint :service_occurrence_definitions,
      "time_zone IS NOT NULL AND btrim(time_zone) <> ''",
      name: "service_occurrence_definitions_time_zone"
    add_check_constraint :service_occurrence_definitions,
      "lock_version >= 0",
      name: "service_occurrence_definitions_lock_version"
  end

  def create_supplier_resource_definitions
    create_table :supplier_resource_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.string :name, null: false, limit: 160
      table.string :description, limit: 2000
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_definition_indexes(:supplier_resource_definitions, stable: :supplier_resource)
    add_version_fk(:supplier_resource_definitions)
    add_resource_fk(:supplier_resource_definitions)
    add_check_constraint :supplier_resource_definitions,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "supplier_resource_definitions_name"
    add_check_constraint :supplier_resource_definitions,
      "description IS NULL OR (btrim(description) <> '' AND char_length(description) <= 2000)",
      name: "supplier_resource_definitions_description"
    add_check_constraint :supplier_resource_definitions,
      "position > 0",
      name: "supplier_resource_definitions_position_positive"
    add_check_constraint :supplier_resource_definitions,
      "lock_version >= 0",
      name: "supplier_resource_definitions_lock_version"

    execute <<~SQL
      ALTER TABLE supplier_resource_definitions
        ADD CONSTRAINT supplier_resource_definitions_position_unique
        UNIQUE (supplier_arrangement_version_id, arrangement_item_id, position)
        DEFERRABLE INITIALLY DEFERRED;
    SQL
  end

  def add_identity_indexes(table_name, parent:)
    add_index table_name, [ :id, :agency_id ],
      unique: true,
      name: "index_#{table_name}_on_id_and_agency_id"
    add_index table_name, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_#{table_name}_on_id_departure_agency"

    parent_columns =
      if parent == :supplier_arrangement
        [ :id, :supplier_arrangement_id, :departure_id, :agency_id ]
      else
        [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ]
      end
    add_index table_name, parent_columns,
      unique: true,
      name: "index_#{table_name}_on_full_owner"
  end

  def add_definition_indexes(table_name, stable:)
    stable_column = :"#{stable}_id"
    add_index table_name, [ :id, :agency_id ],
      unique: true,
      name: "index_#{table_name}_on_id_and_agency_id"
    add_index table_name, [ :id, :departure_id, :agency_id ],
      unique: true,
      name: "index_#{table_name}_on_id_departure_agency"
    add_index table_name, [ :supplier_arrangement_version_id, stable_column ],
      unique: true,
      name: "index_#{table_name}_on_version_and_stable_id"
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

  def add_supplier_fk(table_name, column, name)
    add_foreign_key table_name, :suppliers,
      column: [ column, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: name
  end

  def create_immutable_owner_triggers
    execute <<~SQL
      CREATE FUNCTION reject_supplier_arrangement_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.contracting_supplier_id IS DISTINCT FROM OLD.contracting_supplier_id THEN
          RAISE EXCEPTION 'supplier arrangement owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_arrangements_reject_owner_change
      BEFORE UPDATE ON supplier_arrangements
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_arrangement_owner_change();

      CREATE FUNCTION reject_supplier_arrangement_version_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.version_number IS DISTINCT FROM OLD.version_number THEN
          RAISE EXCEPTION 'supplier arrangement version owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_arrangement_versions_reject_owner_change
      BEFORE UPDATE ON supplier_arrangement_versions
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_arrangement_version_owner_change();

      CREATE FUNCTION reject_arrangement_item_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id THEN
          RAISE EXCEPTION 'arrangement item owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER arrangement_items_reject_owner_change
      BEFORE UPDATE ON arrangement_items
      FOR EACH ROW EXECUTE FUNCTION reject_arrangement_item_owner_change();

      CREATE FUNCTION reject_service_occurrence_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
          RAISE EXCEPTION 'service occurrence owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_occurrences_reject_owner_change
      BEFORE UPDATE ON service_occurrences
      FOR EACH ROW EXECUTE FUNCTION reject_service_occurrence_owner_change();

      CREATE FUNCTION reject_supplier_resource_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.arrangement_item_id IS DISTINCT FROM OLD.arrangement_item_id THEN
          RAISE EXCEPTION 'supplier resource owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_resources_reject_owner_change
      BEFORE UPDATE ON supplier_resources
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_resource_owner_change();
    SQL

    create_definition_owner_trigger(
      :arrangement_item_definitions,
      :arrangement_item,
      "arrangement item definition owner is immutable"
    )
    create_definition_owner_trigger(
      :service_occurrence_definitions,
      :service_occurrence,
      "service occurrence definition owner is immutable",
      extra_columns: [ :arrangement_item_id ]
    )
    create_definition_owner_trigger(
      :supplier_resource_definitions,
      :supplier_resource,
      "supplier resource definition owner is immutable",
      extra_columns: [ :arrangement_item_id ]
    )
  end

  def create_definition_owner_trigger(table_name, stable_name, message, extra_columns: [])
    function_name = "reject_#{table_name.to_s.singularize}_owner_change"
    stable_column = "#{stable_name}_id"
    owner_columns = %w[
      agency_id
      departure_id
      supplier_arrangement_id
      supplier_arrangement_version_id
    ] + extra_columns.map(&:to_s) + [ stable_column ]
    comparisons = owner_columns.map do |column|
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

  def create_time_zone_trigger
    execute <<~SQL
      CREATE FUNCTION reject_invalid_service_occurrence_definition_zone() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM pg_timezone_names
          WHERE name = NEW.time_zone
        ) THEN
          RAISE EXCEPTION 'service occurrence definition time_zone is not a recognized IANA timezone';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_occurrence_definitions_reject_invalid_zone
      BEFORE INSERT OR UPDATE OF time_zone ON service_occurrence_definitions
      FOR EACH ROW EXECUTE FUNCTION reject_invalid_service_occurrence_definition_zone();
    SQL
  end

  def quoted_values(values)
    values.map { |value| quote(value) }.join(", ")
  end
end
