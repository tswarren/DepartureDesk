# frozen_string_literal: true

class CreateM4bServiceOfferPrices < ActiveRecord::Migration[8.1]
  CLIENT_ROLES = %w[base_price named_discount named_surcharge tax_fee].freeze
  CALCULATION_KINDS = %w[fixed unit_rate percentage].freeze
  UNIT_BASES = %w[
    persons resource_units nights person_nights resource_nights
    occupancy_positions occupancy_position_nights
  ].freeze
  PERCENTAGE_TREATMENTS = %w[additive included].freeze
  BASE_DIRECTIONS = %w[add subtract].freeze

  def up
    create_price_definitions
    create_price_components
    create_price_component_bases
    create_triggers
  end

  def down
    drop_table :service_offer_price_component_bases
    drop_table :service_offer_price_components
    drop_table :service_offer_price_definitions
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_service_offer_price_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_service_offer_price_component_owner_change();
      DROP FUNCTION IF EXISTS reject_service_offer_price_component_base_owner_change();
      DROP FUNCTION IF EXISTS validate_service_offer_price_component();
      DROP FUNCTION IF EXISTS validate_service_offer_price_component_base();
    SQL
  end

  private

  def create_price_definitions
    create_table :service_offer_price_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :currency, null: false, limit: 3
      table.string :mode, null: false, default: "calculated"
      table.string :rounding_mode, null: false, default: "half_up"
      table.string :zero_price_reason, limit: 500
      table.timestamps null: false
    end

    add_index :service_offer_price_definitions, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_price_definitions_on_id_agency"
    add_index :service_offer_price_definitions, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_price_definitions_on_id_departure_agency"
    add_index :service_offer_price_definitions,
      [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_price_definitions_on_full_owner"
    add_index :service_offer_price_definitions, :service_offer_version_id,
      unique: true, name: "index_service_offer_price_definitions_one_per_version"

    add_foreign_key :service_offer_price_definitions, :service_offer_versions,
      column: [ :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_price_definitions_version_fk"
    add_foreign_key :service_offer_price_definitions, :departures,
      column: [ :departure_id, :agency_id, :currency ],
      primary_key: [ :id, :agency_id, :operating_currency ],
      name: "service_offer_price_definitions_departure_currency_fk"

    add_check_constraint :service_offer_price_definitions, "currency ~ '^[A-Z]{3}$'",
      name: "service_offer_price_definitions_currency"
    add_check_constraint :service_offer_price_definitions, "mode IN ('calculated', 'zero_price')",
      name: "service_offer_price_definitions_mode"
    add_check_constraint :service_offer_price_definitions, "rounding_mode = 'half_up'",
      name: "service_offer_price_definitions_rounding_mode"
    add_check_constraint :service_offer_price_definitions,
      "(mode = 'zero_price') = (zero_price_reason IS NOT NULL)",
      name: "service_offer_price_definitions_zero_reason_pair"
    add_check_constraint :service_offer_price_definitions,
      "zero_price_reason IS NULL OR (btrim(zero_price_reason) <> '' AND char_length(zero_price_reason) <= 500)",
      name: "service_offer_price_definitions_zero_reason"
  end

  def create_price_components
    create_table :service_offer_price_components, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.uuid :service_offer_price_definition_id, null: false
      table.string :label, null: false, limit: 160
      table.string :client_role, null: false
      table.string :calculation_kind, null: false
      table.bigint :amount_minor_units
      table.decimal :rate, precision: 20, scale: 10
      table.string :quantity_basis
      table.string :percentage_treatment
      table.string :client_rate_category_key, limit: 80
      table.string :occupancy_position_key, limit: 40
      table.integer :position, null: false
      table.timestamps null: false
    end

    add_index :service_offer_price_components, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_price_components_on_id_agency"
    add_index :service_offer_price_components, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_price_components_on_id_departure_agency"
    add_index :service_offer_price_components,
      [ :id, :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_price_components_on_full_owner"
    add_index :service_offer_price_components, [ :service_offer_price_definition_id, :position ],
      unique: true, name: "index_service_offer_price_components_on_definition_position"
    execute <<~SQL
      CREATE UNIQUE INDEX index_service_offer_price_components_one_base_selector
        ON service_offer_price_components
        (service_offer_price_definition_id, client_rate_category_key, occupancy_position_key)
        NULLS NOT DISTINCT
        WHERE client_role = 'base_price';
    SQL

    add_foreign_key :service_offer_price_components, :service_offer_price_definitions,
      column: [ :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_price_components_definition_fk"

    add_check_constraint :service_offer_price_components,
      "btrim(label) <> '' AND char_length(label) <= 160",
      name: "service_offer_price_components_label"
    add_check_constraint :service_offer_price_components,
      "client_role IN ('#{CLIENT_ROLES.join("', '")}')",
      name: "service_offer_price_components_client_role"
    add_check_constraint :service_offer_price_components,
      "calculation_kind IN ('#{CALCULATION_KINDS.join("', '")}')",
      name: "service_offer_price_components_calculation_kind"
    add_check_constraint :service_offer_price_components,
      "quantity_basis IS NULL OR quantity_basis IN ('service_instances', '#{UNIT_BASES.join("', '")}')",
      name: "service_offer_price_components_quantity_basis"
    add_check_constraint :service_offer_price_components,
      "amount_minor_units IS NULL OR amount_minor_units >= 0",
      name: "service_offer_price_components_amount_nonnegative"
    add_check_constraint :service_offer_price_components,
      "rate IS NULL OR rate >= 0",
      name: "service_offer_price_components_rate_nonnegative"
    add_check_constraint :service_offer_price_components,
      "percentage_treatment IS NULL OR percentage_treatment IN ('#{PERCENTAGE_TREATMENTS.join("', '")}')",
      name: "service_offer_price_components_percentage_treatment"
    add_check_constraint :service_offer_price_components,
      "percentage_treatment IS DISTINCT FROM 'included' OR client_role = 'tax_fee'",
      name: "service_offer_price_components_included_role"
    add_check_constraint :service_offer_price_components,
      "client_rate_category_key IS NULL OR (btrim(client_rate_category_key) <> '' AND char_length(client_rate_category_key) <= 80)",
      name: "service_offer_price_components_rate_category"
    add_check_constraint :service_offer_price_components,
      "occupancy_position_key IS NULL OR (btrim(occupancy_position_key) <> '' AND char_length(occupancy_position_key) <= 40)",
      name: "service_offer_price_components_occupancy_position"
    add_check_constraint :service_offer_price_components, "position > 0",
      name: "service_offer_price_components_position_positive"
    add_check_constraint :service_offer_price_components, component_shape_check,
      name: "service_offer_price_components_kind_shape"
  end

  def create_price_component_bases
    create_table :service_offer_price_component_bases, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.uuid :service_offer_price_definition_id, null: false
      table.uuid :service_offer_price_component_id, null: false
      table.uuid :base_component_id, null: false
      table.string :direction, null: false
      table.integer :position, null: false
      table.timestamps null: false
    end

    add_index :service_offer_price_component_bases, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_price_component_bases_on_id_agency"
    add_index :service_offer_price_component_bases,
      [ :service_offer_price_component_id, :base_component_id ],
      unique: true, name: "index_service_offer_price_component_bases_on_pair"
    add_index :service_offer_price_component_bases, [ :service_offer_price_component_id, :position ],
      unique: true, name: "index_service_offer_price_component_bases_on_position"
    add_index :service_offer_price_component_bases, :base_component_id,
      name: "index_service_offer_price_component_bases_on_base"

    add_foreign_key :service_offer_price_component_bases, :service_offer_price_definitions,
      column: [ :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_price_component_bases_definition_fk"
    add_foreign_key :service_offer_price_component_bases, :service_offer_price_components,
      column: [ :service_offer_price_component_id, :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_price_component_bases_component_fk"
    add_foreign_key :service_offer_price_component_bases, :service_offer_price_components,
      column: [ :base_component_id, :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_price_definition_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_price_component_bases_base_fk"

    add_check_constraint :service_offer_price_component_bases,
      "direction IN ('#{BASE_DIRECTIONS.join("', '")}')",
      name: "service_offer_price_component_bases_direction"
    add_check_constraint :service_offer_price_component_bases, "position > 0",
      name: "service_offer_price_component_bases_position_positive"
    add_check_constraint :service_offer_price_component_bases,
      "service_offer_price_component_id <> base_component_id",
      name: "service_offer_price_component_bases_not_self"
  end

  def create_triggers
    execute <<~SQL
      CREATE FUNCTION reject_service_offer_price_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id THEN
          RAISE EXCEPTION 'service offer price definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER service_offer_price_definitions_reject_owner_change
        BEFORE UPDATE ON public.service_offer_price_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_price_definition_owner_change();

      CREATE FUNCTION reject_service_offer_price_component_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id
          OR NEW.service_offer_price_definition_id IS DISTINCT FROM OLD.service_offer_price_definition_id THEN
          RAISE EXCEPTION 'service offer price component owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER service_offer_price_components_reject_owner_change
        BEFORE UPDATE ON public.service_offer_price_components
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_price_component_owner_change();

      CREATE FUNCTION reject_service_offer_price_component_base_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id
          OR NEW.service_offer_price_definition_id IS DISTINCT FROM OLD.service_offer_price_definition_id
          OR NEW.service_offer_price_component_id IS DISTINCT FROM OLD.service_offer_price_component_id
          OR NEW.base_component_id IS DISTINCT FROM OLD.base_component_id THEN
          RAISE EXCEPTION 'service offer price component base owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER service_offer_price_component_bases_reject_owner_change
        BEFORE UPDATE ON public.service_offer_price_component_bases
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_price_component_base_owner_change();

      CREATE TRIGGER service_offer_price_definitions_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.service_offer_price_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();
      CREATE TRIGGER service_offer_price_components_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.service_offer_price_components
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();
      CREATE TRIGGER service_offer_price_component_bases_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.service_offer_price_component_bases
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();

      CREATE FUNCTION validate_service_offer_price_component() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE definition_mode text;
      BEGIN
        SELECT mode INTO definition_mode
          FROM service_offer_price_definitions
         WHERE id = NEW.service_offer_price_definition_id;
        IF definition_mode <> 'calculated' THEN
          RAISE EXCEPTION 'zero-price definitions cannot contain components';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER service_offer_price_components_validate
        BEFORE INSERT OR UPDATE ON public.service_offer_price_components
        FOR EACH ROW EXECUTE FUNCTION validate_service_offer_price_component();

      CREATE FUNCTION validate_service_offer_price_component_base() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE component_position integer;
      DECLARE component_kind text;
      DECLARE base_position integer;
      DECLARE base_treatment text;
      BEGIN
        SELECT position, calculation_kind INTO component_position, component_kind
          FROM service_offer_price_components
         WHERE id = NEW.service_offer_price_component_id
           AND service_offer_price_definition_id = NEW.service_offer_price_definition_id;
        SELECT position, percentage_treatment INTO base_position, base_treatment
          FROM service_offer_price_components
         WHERE id = NEW.base_component_id
           AND service_offer_price_definition_id = NEW.service_offer_price_definition_id;
        IF component_position IS NULL OR base_position IS NULL OR base_position >= component_position THEN
          RAISE EXCEPTION 'price component base must be an earlier component in the same definition';
        END IF;
        IF component_kind <> 'percentage' THEN
          RAISE EXCEPTION 'only percentage price components accept bases';
        END IF;
        IF base_treatment = 'included' THEN
          RAISE EXCEPTION 'an included-tax allocation cannot be a later percentage base';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER service_offer_price_component_bases_validate
        BEFORE INSERT OR UPDATE ON public.service_offer_price_component_bases
        FOR EACH ROW EXECUTE FUNCTION validate_service_offer_price_component_base();
    SQL
  end

  def component_shape_check
    <<~SQL.squish
      (
        calculation_kind = 'fixed'
        AND amount_minor_units IS NOT NULL
        AND quantity_basis = 'service_instances'
        AND rate IS NULL
        AND percentage_treatment IS NULL
      ) OR (
        calculation_kind = 'unit_rate'
        AND amount_minor_units IS NOT NULL
        AND quantity_basis IN ('#{UNIT_BASES.join("', '")}')
        AND rate IS NULL
        AND percentage_treatment IS NULL
      ) OR (
        calculation_kind = 'percentage'
        AND rate IS NOT NULL
        AND percentage_treatment IN ('#{PERCENTAGE_TREATMENTS.join("', '")}')
        AND amount_minor_units IS NULL
        AND quantity_basis IS NULL
      )
    SQL
  end
end
