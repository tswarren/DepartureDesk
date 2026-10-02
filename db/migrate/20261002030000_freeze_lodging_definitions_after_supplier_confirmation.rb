# frozen_string_literal: true

class FreezeLodgingDefinitionsAfterSupplierConfirmation < ActiveRecord::Migration[8.1]
  TABLES = %w[
    arrangement_item_definitions
    service_occurrence_definitions
    supplier_resource_definitions
    capacity_pair_definitions
    capacity_pool_definitions
    supplier_cost_sources
    supplier_cost_definitions
    supplier_cost_components
    supplier_deadline_definitions
    supplier_deposit_requirement_definitions
    supplier_deadline_definition_coverage_links
    supplier_deposit_requirement_definition_coverage_links
  ].freeze

  def up
    execute <<~SQL
      CREATE FUNCTION public.reject_confirmed_lodging_definition_mutation() RETURNS trigger
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
          frozen := row_record.category = 'lodging'
            OR (TG_OP = 'UPDATE' AND OLD.category = 'lodging');
        ELSIF TG_TABLE_NAME IN (
          'service_occurrence_definitions', 'supplier_resource_definitions',
          'capacity_pair_definitions', 'capacity_pool_definitions'
        ) THEN
          frozen := EXISTS (
            SELECT 1 FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.arrangement_item_id = row_record.arrangement_item_id
               AND definitions.category = 'lodging'
          );
        ELSIF TG_TABLE_NAME = 'supplier_cost_sources' THEN
          frozen := EXISTS (
            SELECT 1 FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.category = 'lodging'
          ) AND (
            row_record.arrangement_item_id IS NULL OR EXISTS (
              SELECT 1 FROM arrangement_item_definitions definitions
               WHERE definitions.supplier_arrangement_version_id = version_id
                 AND definitions.arrangement_item_id = row_record.arrangement_item_id
                 AND definitions.category = 'lodging'
            )
          );
        ELSIF TG_TABLE_NAME = 'supplier_cost_definitions' THEN
          SELECT arrangement_item_id INTO item_id
            FROM supplier_cost_sources
           WHERE id = row_record.supplier_cost_source_id;
          frozen := EXISTS (
            SELECT 1 FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.category = 'lodging'
          ) AND (
            item_id IS NULL OR EXISTS (
              SELECT 1 FROM arrangement_item_definitions definitions
               WHERE definitions.supplier_arrangement_version_id = version_id
                 AND definitions.arrangement_item_id = item_id
                 AND definitions.category = 'lodging'
            )
          );
        ELSIF TG_TABLE_NAME = 'supplier_cost_components' THEN
          SELECT sources.arrangement_item_id INTO item_id
            FROM supplier_cost_definitions definitions
            JOIN supplier_cost_sources sources ON sources.id = definitions.supplier_cost_source_id
           WHERE definitions.id = row_record.supplier_cost_definition_id;
          frozen := EXISTS (
            SELECT 1 FROM arrangement_item_definitions item_definitions
             WHERE item_definitions.supplier_arrangement_version_id = version_id
               AND item_definitions.category = 'lodging'
          ) AND (
            item_id IS NULL OR EXISTS (
              SELECT 1 FROM arrangement_item_definitions item_definitions
               WHERE item_definitions.supplier_arrangement_version_id = version_id
                 AND item_definitions.arrangement_item_id = item_id
                 AND item_definitions.category = 'lodging'
            )
          );
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definitions' THEN
          frozen := EXISTS (
            SELECT 1
              FROM supplier_deadline_definition_coverage_links links
              JOIN arrangement_item_definitions definitions
                ON definitions.supplier_arrangement_version_id = links.supplier_arrangement_version_id
               AND definitions.arrangement_item_id = links.arrangement_item_id
               AND definitions.category = 'lodging'
             WHERE links.supplier_deadline_definition_id = row_record.id
          );
        ELSIF TG_TABLE_NAME = 'supplier_deposit_requirement_definitions' THEN
          frozen := EXISTS (
            SELECT 1
              FROM supplier_deposit_requirement_definition_coverage_links links
              JOIN arrangement_item_definitions definitions
                ON definitions.supplier_arrangement_version_id = links.supplier_arrangement_version_id
               AND definitions.arrangement_item_id = links.arrangement_item_id
               AND definitions.category = 'lodging'
             WHERE links.supplier_deposit_requirement_definition_id = row_record.id
          );
        ELSIF TG_TABLE_NAME IN (
          'supplier_deadline_definition_coverage_links',
          'supplier_deposit_requirement_definition_coverage_links'
        ) THEN
          frozen := EXISTS (
            SELECT 1 FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.arrangement_item_id = row_record.arrangement_item_id
               AND definitions.category = 'lodging'
          );
        END IF;

        IF frozen THEN
          RAISE EXCEPTION 'lodging agreement definitions are immutable after Supplier confirmation';
        END IF;

        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    TABLES.each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_confirmed_lodging
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_confirmed_lodging_definition_mutation();
      SQL
    end
  end

  def down
    TABLES.each do |table|
      execute "DROP TRIGGER IF EXISTS #{table}_reject_confirmed_lodging ON public.#{table}"
    end
    execute "DROP FUNCTION IF EXISTS public.reject_confirmed_lodging_definition_mutation()"
  end
end
