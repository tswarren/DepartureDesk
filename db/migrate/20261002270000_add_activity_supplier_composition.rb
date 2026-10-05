# frozen_string_literal: true

class AddActivitySupplierComposition < ActiveRecord::Migration[8.1]
  ACTIVITY_TABLES = %w[
    arrangement_item_definitions
    service_occurrence_definitions
    supplier_resource_definitions
    capacity_pair_definitions
    capacity_pool_definitions
    supplier_cost_sources
    supplier_cost_definitions
    supplier_cost_components
    supplier_deadline_definitions
    supplier_deadline_definition_coverage_links
    supplier_operating_threshold_definitions
    supplier_payment_requirement_definitions
  ].freeze

  def up
    change_agreement_reference_kinds!(include_rate_inclusions: true)
    create_threshold_definitions!
    create_payment_requirements!
    create_threshold_outcomes!
    execute <<~SQL
      CREATE FUNCTION public.reject_confirmed_activity_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
  version_id uuid;
  item_id uuid;
  version_status text;
  frozen boolean := false;
  row_record record;
BEGIN
  row_record := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  version_id := row_record.supplier_arrangement_version_id;

  SELECT status INTO version_status
    FROM supplier_arrangement_versions WHERE id = version_id FOR SHARE;

  IF NOT EXISTS (
    SELECT 1 FROM supplier_confirmations WHERE supplier_arrangement_version_id = version_id
  ) THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME IN (
    'supplier_operating_threshold_definitions', 'supplier_payment_requirement_definitions'
  ) THEN
    frozen := true;
  ELSIF version_status IS DISTINCT FROM 'draft' THEN
    frozen := false;
  ELSIF TG_TABLE_NAME = 'arrangement_item_definitions' THEN
          frozen := row_record.category = 'activity_attraction'
            OR (TG_OP = 'UPDATE' AND OLD.category = 'activity_attraction');
        ELSIF TG_TABLE_NAME IN (
          'service_occurrence_definitions', 'supplier_resource_definitions',
          'capacity_pair_definitions', 'capacity_pool_definitions', 'supplier_cost_sources'
        ) THEN
          frozen := public.activity_attraction_item(version_id, row_record.arrangement_item_id);
        ELSIF TG_TABLE_NAME = 'supplier_cost_definitions' THEN
          SELECT arrangement_item_id INTO item_id
            FROM supplier_cost_sources WHERE id = row_record.supplier_cost_source_id;
          frozen := public.activity_attraction_item(version_id, item_id);
        ELSIF TG_TABLE_NAME = 'supplier_cost_components' THEN
          SELECT sources.arrangement_item_id INTO item_id
            FROM supplier_cost_definitions definitions
            JOIN supplier_cost_sources sources ON sources.id = definitions.supplier_cost_source_id
           WHERE definitions.id = row_record.supplier_cost_definition_id;
          frozen := public.activity_attraction_item(version_id, item_id);
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definitions' THEN
          frozen := EXISTS (
            SELECT 1 FROM supplier_deadline_definition_coverage_links links
             WHERE links.supplier_deadline_definition_id = row_record.id
               AND public.activity_attraction_item(version_id, links.arrangement_item_id)
          );
        ELSIF TG_TABLE_NAME = 'supplier_deadline_definition_coverage_links' THEN
          frozen := public.activity_attraction_item(version_id, row_record.arrangement_item_id);
        END IF;

        IF frozen THEN
          RAISE EXCEPTION 'activity agreement definitions are immutable after Supplier confirmation';
        END IF;

        IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
        RETURN NEW;
      END;
      $$;

      CREATE FUNCTION public.activity_attraction_item(version_id uuid, item_id uuid) RETURNS boolean
      LANGUAGE sql STABLE AS $$
        SELECT EXISTS (
          SELECT 1 FROM arrangement_item_definitions definitions
           WHERE definitions.supplier_arrangement_version_id = version_id
             AND definitions.arrangement_item_id = item_id
             AND definitions.category = 'activity_attraction'
        );
      $$;

      CREATE FUNCTION public.reject_activity_outcome_revision() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'activity operating outcomes are append-only history';
      END;
      $$;

      CREATE FUNCTION public.reject_ungoverning_activity_outcome() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        governing_id uuid;
        definition_version_id uuid;
        arrangement_status text;
      BEGIN
        SELECT governing_version_id, status INTO governing_id, arrangement_status
          FROM supplier_arrangements WHERE id = NEW.supplier_arrangement_id;
        SELECT supplier_arrangement_version_id INTO definition_version_id
          FROM supplier_operating_threshold_definitions
         WHERE id = NEW.supplier_operating_threshold_definition_id;

        IF arrangement_status IS DISTINCT FROM 'active'
          OR definition_version_id IS DISTINCT FROM governing_id
          OR NOT EXISTS (
            SELECT 1 FROM supplier_confirmations
             WHERE supplier_arrangement_version_id = definition_version_id
          ) THEN
          RAISE EXCEPTION 'activity operating outcomes attach only to the Supplier-confirmed governing threshold';
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL

    ACTIVITY_TABLES.each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_confirmed_activity
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_confirmed_activity_definition_mutation();
      SQL
    end

    execute <<~SQL
      CREATE TRIGGER supplier_operating_threshold_outcomes_append_only
        BEFORE UPDATE OR DELETE ON public.supplier_operating_threshold_outcomes
        FOR EACH ROW EXECUTE FUNCTION reject_activity_outcome_revision();
      CREATE TRIGGER supplier_operating_threshold_outcomes_governing_only
        BEFORE INSERT ON public.supplier_operating_threshold_outcomes
        FOR EACH ROW EXECUTE FUNCTION reject_ungoverning_activity_outcome();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_operating_threshold_outcomes_governing_only ON public.supplier_operating_threshold_outcomes;
      DROP TRIGGER IF EXISTS supplier_operating_threshold_outcomes_append_only ON public.supplier_operating_threshold_outcomes;
    SQL
    ACTIVITY_TABLES.each do |table|
      execute "DROP TRIGGER IF EXISTS #{table}_reject_confirmed_activity ON public.#{table}"
    end
    execute <<~SQL
      DROP FUNCTION IF EXISTS public.reject_ungoverning_activity_outcome();
      DROP FUNCTION IF EXISTS public.reject_activity_outcome_revision();
      DROP FUNCTION IF EXISTS public.reject_confirmed_activity_definition_mutation();
      DROP FUNCTION IF EXISTS public.activity_attraction_item(uuid, uuid);
    SQL
    drop_table :supplier_operating_threshold_outcomes
    drop_table :supplier_payment_requirement_definitions
    drop_table :supplier_operating_threshold_definitions
    change_agreement_reference_kinds!(include_rate_inclusions: false)
  end

  private

  def change_agreement_reference_kinds!(include_rate_inclusions:)
    item_kinds = %w[deposit_derivation attrition deposit_refund]
    item_kinds << "rate_inclusions" if include_rate_inclusions
    all_kinds = item_kinds + %w[destination_fee additional_nights early_departure cancellation]
    optional = %w[destination_fee additional_nights early_departure cancellation]
    execute "ALTER TABLE supplier_agreement_references DROP CONSTRAINT agreement_references_kind"
    execute <<~SQL
      ALTER TABLE supplier_agreement_references
        ADD CONSTRAINT agreement_references_kind CHECK (
          kind IN (#{sql_list(all_kinds)})
          AND (
            (kind IN (#{sql_list(item_kinds)}) AND arrangement_item_id IS NOT NULL)
            OR kind IN (#{sql_list(optional)})
          )
        )
    SQL
  end

  def sql_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end

  def create_threshold_definitions!
    create_table :supplier_operating_threshold_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id
      table.string :threshold_kind, null: false
      table.string :quantity_basis, null: false
      table.integer :minimum_quantity, null: false
      table.string :below_threshold_authority, null: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    add_index :supplier_operating_threshold_definitions,
      [ :supplier_arrangement_version_id, :arrangement_item_id ],
      unique: true, name: "index_operating_thresholds_on_version_item"
    add_index :supplier_operating_threshold_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_operating_thresholds_on_lineage_owner"
    add_foreign_key :supplier_operating_threshold_definitions, :agencies
    add_foreign_key :supplier_operating_threshold_definitions, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "operating_thresholds_version_fk"
    add_foreign_key :supplier_operating_threshold_definitions, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "operating_thresholds_item_fk"
    add_check_constraint :supplier_operating_threshold_definitions,
      "threshold_kind = 'minimum_enrollment' AND quantity_basis = 'persons' AND below_threshold_authority = 'supplier_decision' AND minimum_quantity > 0 AND lock_version >= 0",
      name: "operating_thresholds_activity_shape"
  end

  def create_payment_requirements!
    create_table :supplier_payment_requirement_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :supplier_cost_component_id, null: false
      table.string :kind, null: false
      table.date :due_on, null: false
      table.string :currency, null: false, limit: 3
      table.string :quantity_status, null: false
      table.integer :position, null: false
      table.integer :lock_version, null: false, default: 0
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    add_index :supplier_payment_requirement_definitions,
      [ :supplier_arrangement_version_id, :arrangement_item_id, :kind ],
      unique: true, name: "index_payment_requirements_on_version_item_kind"
    add_index :supplier_payment_requirement_definitions,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_payment_requirements_on_lineage_owner"
    add_foreign_key :supplier_payment_requirement_definitions, :agencies
    add_foreign_key :supplier_payment_requirement_definitions, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "payment_requirements_version_fk"
    add_foreign_key :supplier_payment_requirement_definitions, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "payment_requirements_item_fk"
    add_foreign_key :supplier_payment_requirement_definitions, :supplier_cost_components,
      column: [ :supplier_cost_component_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "payment_requirements_component_fk"
    add_check_constraint :supplier_payment_requirement_definitions,
      "kind = 'full_payment' AND quantity_status = 'authoritative_quantity_unavailable' AND char_length(currency) = 3 AND lock_version >= 0",
      name: "payment_requirements_unresolved_quantity"
  end

  def create_threshold_outcomes!
    create_table :supplier_operating_threshold_outcomes, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_operating_threshold_definition_id, null: false
      table.integer :observed_quantity
      table.string :outcome, null: false
      table.string :evidence, null: false, limit: 2000
      table.date :occurred_on, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false
      table.timestamps null: false
    end
    add_index :supplier_operating_threshold_outcomes, :supplier_operating_threshold_definition_id,
      unique: true, name: "index_operating_outcomes_on_threshold"
    add_foreign_key :supplier_operating_threshold_outcomes, :agencies
    add_foreign_key :supplier_operating_threshold_outcomes, :supplier_operating_threshold_definitions,
      column: [ :supplier_operating_threshold_definition_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "operating_outcomes_threshold_fk"
    add_foreign_key :supplier_operating_threshold_outcomes, :agency_users, column: :recorded_by_id
    add_check_constraint :supplier_operating_threshold_outcomes,
      "outcome IN ('operate', 'cancel') AND char_length(btrim(evidence)) BETWEEN 1 AND 2000 AND (observed_quantity IS NULL OR observed_quantity >= 0)",
      name: "operating_outcomes_shape"
  end
end
