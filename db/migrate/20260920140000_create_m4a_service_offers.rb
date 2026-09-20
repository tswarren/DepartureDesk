# frozen_string_literal: true

class CreateM4aServiceOffers < ActiveRecord::Migration[8.1]
  FULFILLMENT_BASES = %w[m3_backed on_request agency_fulfilled externally_fulfilled].freeze
  VERSION_STATUSES = %w[draft abandoned published superseded retired].freeze
  MEMBERSHIP_KINDS = %w[required alternative].freeze
  TITLE_PROVENANCES = %w[source_name staff_entered].freeze
  DESCRIPTION_PROVENANCES = %w[source_description staff_entered none].freeze

  def up
    add_binding_target_indexes
    create_service_offers
    create_service_offer_versions
    create_service_offer_definitions
    create_service_offer_source_bindings
    create_owner_immutability_triggers
    create_non_draft_mutation_guard
    create_ancestry_trigger
    create_version_lifecycle_trigger
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS service_offer_source_bindings_reject_ancestry
        ON public.service_offer_source_bindings;
      DROP TRIGGER IF EXISTS service_offer_definitions_reject_non_draft_mutation
        ON public.service_offer_definitions;
      DROP TRIGGER IF EXISTS service_offer_source_bindings_reject_non_draft_mutation
        ON public.service_offer_source_bindings;
      DROP TRIGGER IF EXISTS service_offer_versions_reject_invalid_lifecycle
        ON public.service_offer_versions;
      DROP FUNCTION IF EXISTS reject_invalid_service_offer_source_binding_ancestry();
      DROP FUNCTION IF EXISTS reject_non_draft_service_offer_version_definition_mutation();
      DROP FUNCTION IF EXISTS reject_invalid_service_offer_version_lifecycle();
      DROP FUNCTION IF EXISTS reject_service_offer_owner_change();
      DROP FUNCTION IF EXISTS reject_service_offer_version_owner_change();
      DROP FUNCTION IF EXISTS reject_service_offer_definition_owner_change();
      DROP FUNCTION IF EXISTS reject_service_offer_source_binding_owner_change();
    SQL

    drop_table :service_offer_source_bindings
    drop_table :service_offer_definitions
    drop_table :service_offer_versions
    drop_table :service_offers

    remove_index :arrangement_item_definitions, name: "index_item_defs_on_offer_binding_owner"
    remove_index :service_occurrence_definitions, name: "index_occurrence_defs_on_offer_binding_owner"
    remove_index :supplier_resource_definitions, name: "index_resource_defs_on_offer_binding_owner"
    remove_index :capacity_pool_definitions, name: "index_pool_defs_on_offer_binding_owner"
  end

  private

  def add_binding_target_indexes
    add_index :arrangement_item_definitions,
      [ :id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id ],
      unique: true,
      name: "index_item_defs_on_offer_binding_owner"
    add_index :service_occurrence_definitions,
      [ :id, :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_occurrence_defs_on_offer_binding_owner"
    add_index :supplier_resource_definitions,
      [ :id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_resource_defs_on_offer_binding_owner"
    add_index :capacity_pool_definitions,
      [ :id, :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id,
        :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_pool_defs_on_offer_binding_owner"
  end

  def create_service_offers
    create_table :service_offers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.string :name, null: false, limit: 160
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :service_offers, [ :id, :agency_id ],
      unique: true, name: "index_service_offers_on_id_and_agency_id"
    add_index :service_offers, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offers_on_id_departure_agency"
    add_index :service_offers, [ :agency_id, :departure_id, :name, :id ],
      name: "index_service_offers_on_departure_list"

    add_foreign_key :service_offers, :departures,
      column: [ :departure_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "service_offers_departure_agency_fk"

    add_check_constraint :service_offers,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "service_offers_name"
    add_check_constraint :service_offers,
      "lock_version >= 0",
      name: "service_offers_lock_version"
  end

  def create_service_offer_versions
    create_table :service_offer_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.integer :version_number, null: false
      table.string :status, null: false, default: "draft"
      table.timestamptz :abandoned_at
      table.string :abandoned_reason, limit: 500
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :service_offer_versions, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_versions_on_id_and_agency"
    add_index :service_offer_versions, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_versions_on_id_departure_agency"
    add_index :service_offer_versions,
      [ :id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_versions_on_full_owner"
    add_index :service_offer_versions, [ :service_offer_id, :version_number ],
      unique: true, name: "index_service_offer_versions_on_number"
    add_index :service_offer_versions, :service_offer_id,
      unique: true, where: "status = 'draft'",
      name: "index_service_offer_versions_one_draft"

    add_foreign_key :service_offer_versions, :service_offers,
      column: [ :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "service_offer_versions_offer_fk"

    add_check_constraint :service_offer_versions,
      "version_number > 0",
      name: "service_offer_versions_number_positive"
    add_check_constraint :service_offer_versions,
      "status IN ('#{VERSION_STATUSES.join("', '")}')",
      name: "service_offer_versions_status"
    add_check_constraint :service_offer_versions,
      "(status = 'abandoned' AND abandoned_at IS NOT NULL AND abandoned_reason IS NOT NULL) OR " \
      "(status <> 'abandoned' AND abandoned_at IS NULL AND abandoned_reason IS NULL)",
      name: "service_offer_versions_abandoned_pair"
    add_check_constraint :service_offer_versions,
      "abandoned_reason IS NULL OR (btrim(abandoned_reason) <> '' AND char_length(abandoned_reason) <= 500)",
      name: "service_offer_versions_reason"
    add_check_constraint :service_offer_versions,
      "lock_version >= 0",
      name: "service_offer_versions_lock_version"
  end

  def create_service_offer_definitions
    create_table :service_offer_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :client_title, null: false, limit: 160
      table.string :client_description, limit: 2_000
      table.string :fulfillment_basis, null: false
      table.timestamps null: false
    end

    add_index :service_offer_definitions, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_definitions_on_id_and_agency"
    add_index :service_offer_definitions, [ :id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_definitions_on_id_departure_agency"
    add_index :service_offer_definitions,
      [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_definitions_on_full_owner"
    add_index :service_offer_definitions, :service_offer_version_id,
      unique: true, name: "index_service_offer_definitions_one_per_version"

    add_foreign_key :service_offer_definitions, :service_offer_versions,
      column: [ :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_definitions_version_fk"

    add_check_constraint :service_offer_definitions,
      "btrim(client_title) <> '' AND char_length(client_title) <= 160",
      name: "service_offer_definitions_client_title"
    add_check_constraint :service_offer_definitions,
      "client_description IS NULL OR (btrim(client_description) <> '' AND char_length(client_description) <= 2000)",
      name: "service_offer_definitions_client_description"
    add_check_constraint :service_offer_definitions,
      "fulfillment_basis IN ('#{FULFILLMENT_BASES.join("', '")}')",
      name: "service_offer_definitions_fulfillment_basis"
  end

  def create_service_offer_source_bindings
    create_table :service_offer_source_bindings, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :membership_kind, null: false, default: "required"
      table.string :alternative_group_key, limit: 80
      table.string :alternative_group_label, limit: 160
      table.integer :position, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_definition_id, null: false
      table.uuid :service_occurrence_definition_id
      table.uuid :supplier_resource_definition_id
      table.uuid :capacity_pool_definition_id
      table.boolean :depend_on_item_name, null: false, default: false
      table.boolean :depend_on_item_description, null: false, default: false
      table.boolean :depend_on_occurrence_name, null: false, default: false
      table.boolean :depend_on_occurrence_description, null: false, default: false
      table.boolean :depend_on_resource_name, null: false, default: false
      table.boolean :depend_on_resource_description, null: false, default: false
      table.boolean :depend_on_pool_label, null: false, default: false
      table.boolean :depend_on_pool_unit_label, null: false, default: false
      table.string :client_title_provenance, null: false, default: "source_name"
      table.string :client_description_provenance, null: false, default: "none"
      table.timestamps null: false
    end

    add_index :service_offer_source_bindings, [ :id, :agency_id ],
      unique: true, name: "index_service_offer_source_bindings_on_id_and_agency"
    add_index :service_offer_source_bindings,
      [ :service_offer_version_id, :position ],
      unique: true, name: "index_service_offer_source_bindings_on_position"
    add_index :service_offer_source_bindings,
      [ :service_offer_version_id, :id ],
      name: "index_service_offer_source_bindings_on_version"

    add_foreign_key :service_offer_source_bindings, :service_offer_versions,
      column: [ :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_version_fk"
    add_foreign_key :service_offer_source_bindings, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_arrangement_fk"
    add_foreign_key :service_offer_source_bindings, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_item_fk"
    add_foreign_key :service_offer_source_bindings, :service_occurrences,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_occurrence_fk"
    add_foreign_key :service_offer_source_bindings, :supplier_resources,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_resource_fk"
    add_foreign_key :service_offer_source_bindings, :capacity_pools,
      column: [ :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id,
                :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id,
                     :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_pool_fk"
    add_foreign_key :service_offer_source_bindings, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_arrangement_version_fk"
    add_foreign_key :service_offer_source_bindings, :arrangement_item_definitions,
      column: [ :arrangement_item_definition_id, :arrangement_item_id, :supplier_arrangement_version_id,
                :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_version_id,
                     :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_item_definition_fk"
    add_foreign_key :service_offer_source_bindings, :service_occurrence_definitions,
      column: [ :service_occurrence_definition_id, :service_occurrence_id, :arrangement_item_id,
                :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_occurrence_id, :arrangement_item_id,
                     :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_occurrence_definition_fk"
    add_foreign_key :service_offer_source_bindings, :supplier_resource_definitions,
      column: [ :supplier_resource_definition_id, :supplier_resource_id, :arrangement_item_id,
                :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_resource_id, :arrangement_item_id,
                     :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "service_offer_source_bindings_resource_definition_fk"
    add_foreign_key :service_offer_source_bindings, :capacity_pool_definitions,
      column: [ :capacity_pool_definition_id, :capacity_pool_id, :service_occurrence_id, :supplier_resource_id,
                :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
                :departure_id, :agency_id ],
      primary_key: [ :id, :capacity_pool_id, :service_occurrence_id, :supplier_resource_id,
                     :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id,
                     :departure_id, :agency_id ],
      name: "service_offer_source_bindings_pool_definition_fk"

    add_check_constraint :service_offer_source_bindings,
      "membership_kind IN ('#{MEMBERSHIP_KINDS.join("', '")}')",
      name: "service_offer_source_bindings_membership_kind"
    add_check_constraint :service_offer_source_bindings,
      "(membership_kind = 'required' AND alternative_group_key IS NULL AND alternative_group_label IS NULL) OR " \
      "(membership_kind = 'alternative' AND alternative_group_key IS NOT NULL AND alternative_group_label IS NOT NULL)",
      name: "service_offer_source_bindings_alternative_group"
    add_check_constraint :service_offer_source_bindings,
      "alternative_group_key IS NULL OR (btrim(alternative_group_key) <> '' AND char_length(alternative_group_key) <= 80)",
      name: "service_offer_source_bindings_group_key"
    add_check_constraint :service_offer_source_bindings,
      "alternative_group_label IS NULL OR (btrim(alternative_group_label) <> '' AND char_length(alternative_group_label) <= 160)",
      name: "service_offer_source_bindings_group_label"
    add_check_constraint :service_offer_source_bindings,
      "position > 0",
      name: "service_offer_source_bindings_position"
    add_check_constraint :service_offer_source_bindings,
      "(capacity_pool_id IS NULL) = (capacity_pool_definition_id IS NULL)",
      name: "service_offer_source_bindings_pool_definition_pair"
    add_check_constraint :service_offer_source_bindings,
      "(service_occurrence_id IS NULL) = (service_occurrence_definition_id IS NULL)",
      name: "service_offer_source_bindings_occurrence_definition_pair"
    add_check_constraint :service_offer_source_bindings,
      "(supplier_resource_id IS NULL) = (supplier_resource_definition_id IS NULL)",
      name: "service_offer_source_bindings_resource_definition_pair"
    add_check_constraint :service_offer_source_bindings,
      "capacity_pool_id IS NULL OR (service_occurrence_id IS NOT NULL AND supplier_resource_id IS NOT NULL)",
      name: "service_offer_source_bindings_pool_requires_occurrence_resource"
    add_check_constraint :service_offer_source_bindings,
      "client_title_provenance IN ('#{TITLE_PROVENANCES.join("', '")}')",
      name: "service_offer_source_bindings_title_provenance"
    add_check_constraint :service_offer_source_bindings,
      "client_description_provenance IN ('#{DESCRIPTION_PROVENANCES.join("', '")}')",
      name: "service_offer_source_bindings_description_provenance"
  end

  def create_owner_immutability_triggers
    execute <<~SQL
      CREATE FUNCTION reject_service_offer_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id THEN
          RAISE EXCEPTION 'service offer owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offers_reject_owner_change
        BEFORE UPDATE ON public.service_offers
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_owner_change();

      CREATE FUNCTION reject_service_offer_version_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.version_number IS DISTINCT FROM OLD.version_number THEN
          RAISE EXCEPTION 'service offer version owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_versions_reject_owner_change
        BEFORE UPDATE ON public.service_offer_versions
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_version_owner_change();

      CREATE FUNCTION reject_service_offer_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id THEN
          RAISE EXCEPTION 'service offer definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_definitions_reject_owner_change
        BEFORE UPDATE ON public.service_offer_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_definition_owner_change();

      CREATE FUNCTION reject_service_offer_source_binding_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.service_offer_id IS DISTINCT FROM OLD.service_offer_id
          OR NEW.service_offer_version_id IS DISTINCT FROM OLD.service_offer_version_id THEN
          RAISE EXCEPTION 'service offer source binding owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_source_bindings_reject_owner_change
        BEFORE UPDATE ON public.service_offer_source_bindings
        FOR EACH ROW EXECUTE FUNCTION reject_service_offer_source_binding_owner_change();
    SQL
  end

  def create_non_draft_mutation_guard
    execute <<~SQL
      CREATE FUNCTION reject_non_draft_service_offer_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.service_offer_version_id;
        ELSE
          version_id := OLD.service_offer_version_id;
        END IF;

        SELECT status INTO version_status
        FROM public.service_offer_versions
        WHERE id = version_id;

        IF version_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'exact-version definitions are immutable after leaving draft';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_definitions_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.service_offer_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();

      CREATE TRIGGER service_offer_source_bindings_reject_non_draft_mutation
        BEFORE INSERT OR UPDATE OR DELETE ON public.service_offer_source_bindings
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();
    SQL
  end

  def create_ancestry_trigger
    execute <<~SQL
      CREATE FUNCTION reject_invalid_service_offer_source_binding_ancestry() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_arrangement_id uuid;
        item_arrangement_id uuid;
        occ_item_id uuid;
        res_item_id uuid;
        pool_item_id uuid;
        pool_occ_id uuid;
        pool_res_id uuid;
      BEGIN
        SELECT supplier_arrangement_id INTO version_arrangement_id
        FROM public.supplier_arrangement_versions
        WHERE id = NEW.supplier_arrangement_version_id;

        IF version_arrangement_id IS DISTINCT FROM NEW.supplier_arrangement_id THEN
          RAISE EXCEPTION 'source binding arrangement version is not in the bound arrangement';
        END IF;

        SELECT supplier_arrangement_id INTO item_arrangement_id
        FROM public.arrangement_items
        WHERE id = NEW.arrangement_item_id;

        IF item_arrangement_id IS DISTINCT FROM NEW.supplier_arrangement_id THEN
          RAISE EXCEPTION 'source binding item is not in the bound arrangement';
        END IF;

        IF NEW.service_occurrence_id IS NOT NULL THEN
          SELECT arrangement_item_id INTO occ_item_id
          FROM public.service_occurrences
          WHERE id = NEW.service_occurrence_id;

          IF occ_item_id IS DISTINCT FROM NEW.arrangement_item_id THEN
            RAISE EXCEPTION 'source binding occurrence is not in the bound item';
          END IF;
        END IF;

        IF NEW.supplier_resource_id IS NOT NULL THEN
          SELECT arrangement_item_id INTO res_item_id
          FROM public.supplier_resources
          WHERE id = NEW.supplier_resource_id;

          IF res_item_id IS DISTINCT FROM NEW.arrangement_item_id THEN
            RAISE EXCEPTION 'source binding resource is not in the bound item';
          END IF;
        END IF;

        IF NEW.capacity_pool_id IS NOT NULL THEN
          IF NEW.service_occurrence_id IS NULL OR NEW.supplier_resource_id IS NULL THEN
            RAISE EXCEPTION 'source binding pool requires occurrence and resource';
          END IF;

          SELECT arrangement_item_id, service_occurrence_id, supplier_resource_id
          INTO pool_item_id, pool_occ_id, pool_res_id
          FROM public.capacity_pools
          WHERE id = NEW.capacity_pool_id;

          IF pool_item_id IS DISTINCT FROM NEW.arrangement_item_id
            OR pool_occ_id IS DISTINCT FROM NEW.service_occurrence_id
            OR pool_res_id IS DISTINCT FROM NEW.supplier_resource_id THEN
            RAISE EXCEPTION 'source binding pool is not in the bound occurrence and resource';
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_source_bindings_reject_ancestry
        BEFORE INSERT OR UPDATE ON public.service_offer_source_bindings
        FOR EACH ROW EXECUTE FUNCTION reject_invalid_service_offer_source_binding_ancestry();
    SQL
  end

  def create_version_lifecycle_trigger
    execute <<~SQL
      CREATE FUNCTION reject_invalid_service_offer_version_lifecycle() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
          IF NOT (OLD.status = 'draft' AND NEW.status = 'abandoned') THEN
            RAISE EXCEPTION 'service offer version status transition from % to % is not permitted',
              OLD.status, NEW.status;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER service_offer_versions_reject_invalid_lifecycle
        BEFORE UPDATE ON public.service_offer_versions
        FOR EACH ROW EXECUTE FUNCTION reject_invalid_service_offer_version_lifecycle();
    SQL
  end
end
