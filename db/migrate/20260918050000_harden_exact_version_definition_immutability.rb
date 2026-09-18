# frozen_string_literal: true

class HardenExactVersionDefinitionImmutability < ActiveRecord::Migration[8.1]
  DEFINITION_TABLES = %w[
    arrangement_item_definitions
    service_occurrence_definitions
    supplier_resource_definitions
    capacity_pair_definitions
    capacity_pool_definitions
    supplier_cost_sources
    supplier_cost_definitions
    supplier_cost_components
    supplier_cost_component_bases
    supplier_cost_participant_categories
    supplier_cost_usage_assumptions
    supplier_cost_occupancy_profiles
    supplier_cost_occupancy_profile_positions
    supplier_commitment_trigger_definitions
  ].freeze

  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_non_draft_arrangement_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.supplier_arrangement_version_id;
        ELSE
          version_id := OLD.supplier_arrangement_version_id;
        END IF;

        SELECT status INTO version_status
        FROM public.supplier_arrangement_versions
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
    SQL

    DEFINITION_TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_non_draft_mutation ON public.#{table};
        CREATE TRIGGER #{table}_reject_non_draft_mutation
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();
      SQL
    end

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_supplier_commitment_trigger_definition_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.departure_id IS DISTINCT FROM OLD.departure_id
          OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
          OR NEW.supplier_arrangement_version_id IS DISTINCT FROM OLD.supplier_arrangement_version_id
          OR NEW.copied_from_id IS DISTINCT FROM OLD.copied_from_id
        THEN
          RAISE EXCEPTION 'supplier commitment trigger definition owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_commitment_trigger_definitions_reject_owner_change
        ON public.supplier_commitment_trigger_definitions;
      CREATE TRIGGER supplier_commitment_trigger_definitions_reject_owner_change
        BEFORE UPDATE ON public.supplier_commitment_trigger_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_commitment_trigger_definition_owner_change();
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_illegal_supplier_arrangement_version_lifecycle() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
          IF OLD.status = 'draft' THEN
            RETURN NEW;
          END IF;
          RAISE EXCEPTION 'supplier arrangement version lifecycle is immutable except for accepted transitions';
        END IF;

        IF OLD.status = 'draft' AND NEW.status = 'activated' THEN
          IF NEW.activated_at IS NULL
            OR NEW.superseded_at IS NOT NULL
            OR NEW.abandoned_at IS NOT NULL
            OR NEW.abandoned_reason IS NOT NULL
          THEN
            RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
          END IF;
          RETURN NEW;
        END IF;

        IF OLD.status = 'activated' AND NEW.status = 'superseded' THEN
          IF NEW.activated_at IS DISTINCT FROM OLD.activated_at
            OR NEW.superseded_at IS NULL
            OR NEW.abandoned_at IS NOT NULL
            OR NEW.abandoned_reason IS NOT NULL
          THEN
            RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
          END IF;
          RETURN NEW;
        END IF;

        IF OLD.status = 'draft' AND NEW.status = 'abandoned' THEN
          IF NEW.abandoned_at IS NULL
            OR NEW.abandoned_reason IS NULL
            OR NEW.activated_at IS NOT NULL
            OR NEW.superseded_at IS NOT NULL
          THEN
            RAISE EXCEPTION 'supplier arrangement version lifecycle transition is invalid';
          END IF;
          RETURN NEW;
        END IF;

        RAISE EXCEPTION 'supplier arrangement version lifecycle transition is not permitted';
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_arrangement_versions_reject_illegal_lifecycle
        ON public.supplier_arrangement_versions;
      CREATE TRIGGER supplier_arrangement_versions_reject_illegal_lifecycle
        BEFORE UPDATE ON public.supplier_arrangement_versions
        FOR EACH ROW EXECUTE FUNCTION reject_illegal_supplier_arrangement_version_lifecycle();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_arrangement_versions_reject_illegal_lifecycle
        ON public.supplier_arrangement_versions;
      DROP FUNCTION IF EXISTS reject_illegal_supplier_arrangement_version_lifecycle();
    SQL

    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_commitment_trigger_definitions_reject_owner_change
        ON public.supplier_commitment_trigger_definitions;
      DROP FUNCTION IF EXISTS reject_supplier_commitment_trigger_definition_owner_change();
    SQL

    DEFINITION_TABLES.each do |table|
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{table}_reject_non_draft_mutation ON public.#{table};
      SQL
    end

    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_non_draft_arrangement_version_definition_mutation();
    SQL
  end
end
