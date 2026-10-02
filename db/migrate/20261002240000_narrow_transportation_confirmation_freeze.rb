# frozen_string_literal: true

class NarrowTransportationConfirmationFreeze < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.reject_confirmed_transportation_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        item_id uuid;
        frozen boolean := false;
        row_record record;
      BEGIN
        row_record := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
        version_id := row_record.supplier_arrangement_version_id;

        PERFORM id
          FROM supplier_arrangement_versions
         WHERE id = version_id
           FOR SHARE;

        IF NOT EXISTS (
          SELECT 1 FROM supplier_confirmations WHERE supplier_arrangement_version_id = version_id
        ) THEN
          IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
          RETURN NEW;
        END IF;

        IF TG_TABLE_NAME = 'arrangement_item_definitions' THEN
          item_id := row_record.arrangement_item_id;
          frozen := (
            row_record.category = 'ground_transportation'
            OR (TG_OP = 'UPDATE' AND OLD.category = 'ground_transportation')
          ) AND public.transportation_ceiling_item(version_id, item_id);
        ELSIF TG_TABLE_NAME = 'capacity_pool_definitions' THEN
          frozen := public.transportation_ceiling_item(version_id, row_record.arrangement_item_id)
            OR (TG_OP = 'UPDATE' AND OLD.maximum_total_resource_units IS NOT NULL);
        ELSIF TG_TABLE_NAME IN (
          'service_occurrence_definitions', 'supplier_resource_definitions',
          'capacity_pair_definitions'
        ) THEN
          frozen := public.transportation_ceiling_item(version_id, row_record.arrangement_item_id);
        ELSIF TG_TABLE_NAME = 'supplier_cost_sources' THEN
          frozen := public.transportation_ceiling_item(version_id, row_record.arrangement_item_id);
        ELSIF TG_TABLE_NAME = 'supplier_cost_definitions' THEN
          SELECT arrangement_item_id INTO item_id
            FROM supplier_cost_sources
           WHERE id = row_record.supplier_cost_source_id;
          frozen := public.transportation_ceiling_item(version_id, item_id);
        ELSIF TG_TABLE_NAME = 'supplier_cost_components' THEN
          SELECT sources.arrangement_item_id INTO item_id
            FROM supplier_cost_definitions definitions
            JOIN supplier_cost_sources sources ON sources.id = definitions.supplier_cost_source_id
           WHERE definitions.id = row_record.supplier_cost_definition_id;
          frozen := public.transportation_ceiling_item(version_id, item_id);
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definitions' THEN
          frozen := EXISTS (
            SELECT 1
              FROM supplier_deadline_definition_coverage_links links
             WHERE links.supplier_deadline_definition_id = row_record.id
               AND public.transportation_ceiling_item(version_id, links.arrangement_item_id)
          );
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definition_coverage_links' THEN
          frozen := public.transportation_ceiling_item(version_id, row_record.arrangement_item_id);
        ELSIF TG_TABLE_NAME IN (
          'supplier_amount_due_definitions', 'supplier_amount_due_contributors'
        ) THEN
          frozen := EXISTS (
            SELECT 1 FROM capacity_pool_definitions pools
             WHERE pools.supplier_arrangement_version_id = version_id
               AND pools.maximum_total_resource_units IS NOT NULL
          );
        END IF;

        IF frozen THEN
          RAISE EXCEPTION 'transportation agreement definitions are immutable after Supplier confirmation';
        END IF;

        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION public.transportation_ceiling_item(version_id uuid, item_id uuid) RETURNS boolean
      LANGUAGE sql STABLE AS $$
        SELECT item_id IS NOT NULL AND EXISTS (
          SELECT 1 FROM capacity_pool_definitions pools
           WHERE pools.supplier_arrangement_version_id = version_id
             AND pools.arrangement_item_id = item_id
             AND pools.maximum_total_resource_units IS NOT NULL
        );
      $$;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS public.transportation_ceiling_item(uuid, uuid)"
  end
end
