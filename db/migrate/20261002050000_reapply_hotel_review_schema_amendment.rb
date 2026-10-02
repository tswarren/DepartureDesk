# frozen_string_literal: true

class ReapplyHotelReviewSchemaAmendment < ActiveRecord::Migration[8.1]
  KINDS = %w[
    deposit_derivation attrition deposit_refund
    destination_fee additional_nights early_departure cancellation
  ].freeze
  ITEM_KINDS = %w[deposit_derivation attrition deposit_refund].freeze

  def up
    execute <<~SQL
      ALTER TABLE public.supplier_agreement_reference_absences
        DROP CONSTRAINT IF EXISTS agreement_reference_absences_kind;

      ALTER TABLE public.supplier_agreement_reference_absences
        ADD CONSTRAINT agreement_reference_absences_kind
        CHECK (
          kind IN (#{KINDS.map { |kind| "'#{kind}'" }.join(", ")})
          AND (
            kind NOT IN (#{ITEM_KINDS.map { |kind| "'#{kind}'" }.join(", ")})
            OR arrangement_item_id IS NOT NULL
          )
        );

      CREATE OR REPLACE FUNCTION public.lodging_coverage_affects_version(
        p_version_id uuid,
        p_arrangement_item_id uuid,
        p_service_occurrence_id uuid,
        p_supplier_resource_id uuid,
        p_capacity_pool_id uuid
      ) RETURNS boolean
      LANGUAGE sql STABLE AS $$
        SELECT EXISTS (
          SELECT 1
            FROM arrangement_item_definitions definitions
           WHERE definitions.supplier_arrangement_version_id = p_version_id
             AND definitions.category = 'lodging'
             AND (
               definitions.arrangement_item_id = p_arrangement_item_id
               OR EXISTS (
                 SELECT 1
                   FROM service_occurrences occurrences
                  WHERE occurrences.id = p_service_occurrence_id
                    AND occurrences.arrangement_item_id = definitions.arrangement_item_id
               )
               OR EXISTS (
                 SELECT 1
                   FROM supplier_resources resources
                  WHERE resources.id = p_supplier_resource_id
                    AND resources.arrangement_item_id = definitions.arrangement_item_id
               )
               OR EXISTS (
                 SELECT 1
                   FROM capacity_pools pools
                  WHERE pools.id = p_capacity_pool_id
                    AND pools.arrangement_item_id = definitions.arrangement_item_id
               )
             )
        );
      $$;

      CREATE OR REPLACE FUNCTION public.reject_confirmed_lodging_definition_mutation() RETURNS trigger
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
          SELECT 1
            FROM supplier_confirmations
           WHERE supplier_arrangement_version_id = version_id
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
            SELECT 1
              FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.arrangement_item_id = row_record.arrangement_item_id
               AND definitions.category = 'lodging'
          );
        ELSIF TG_TABLE_NAME = 'supplier_cost_sources' THEN
          frozen := EXISTS (
            SELECT 1
              FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.category = 'lodging'
          ) AND (
            row_record.arrangement_item_id IS NULL OR EXISTS (
              SELECT 1
                FROM arrangement_item_definitions definitions
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
            SELECT 1
              FROM arrangement_item_definitions definitions
             WHERE definitions.supplier_arrangement_version_id = version_id
               AND definitions.category = 'lodging'
          ) AND (
            item_id IS NULL OR EXISTS (
              SELECT 1
                FROM arrangement_item_definitions definitions
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
            SELECT 1
              FROM arrangement_item_definitions item_definitions
             WHERE item_definitions.supplier_arrangement_version_id = version_id
               AND item_definitions.category = 'lodging'
          ) AND (
            item_id IS NULL OR EXISTS (
              SELECT 1
                FROM arrangement_item_definitions item_definitions
               WHERE item_definitions.supplier_arrangement_version_id = version_id
                 AND item_definitions.arrangement_item_id = item_id
                 AND item_definitions.category = 'lodging'
            )
          );
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definitions' THEN
          frozen := EXISTS (
            SELECT 1
              FROM supplier_deadline_definition_coverage_links links
             WHERE links.supplier_deadline_definition_id = row_record.id
               AND public.lodging_coverage_affects_version(
                 version_id, links.arrangement_item_id, links.service_occurrence_id,
                 links.supplier_resource_id, links.capacity_pool_id
               )
          );
        ELSIF TG_TABLE_NAME = 'supplier_deposit_requirement_definitions' THEN
          frozen := EXISTS (
            SELECT 1
              FROM supplier_deposit_requirement_definition_coverage_links links
             WHERE links.supplier_deposit_requirement_definition_id = row_record.id
               AND public.lodging_coverage_affects_version(
                 version_id, links.arrangement_item_id, links.service_occurrence_id,
                 links.supplier_resource_id, links.capacity_pool_id
               )
          );
        ELSIF TG_TABLE_NAME IN (
          'supplier_deadline_definition_coverage_links',
          'supplier_deposit_requirement_definition_coverage_links'
        ) THEN
          frozen := public.lodging_coverage_affects_version(
            version_id, row_record.arrangement_item_id, row_record.service_occurrence_id,
            row_record.supplier_resource_id, row_record.capacity_pool_id
          );
          IF NOT frozen AND TG_OP = 'UPDATE' THEN
            frozen := public.lodging_coverage_affects_version(
              OLD.supplier_arrangement_version_id, OLD.arrangement_item_id, OLD.service_occurrence_id,
              OLD.supplier_resource_id, OLD.capacity_pool_id
            );
          END IF;
        END IF;

        IF frozen THEN
          RAISE EXCEPTION 'lodging agreement definitions are immutable after Supplier confirmation';
        END IF;

        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
