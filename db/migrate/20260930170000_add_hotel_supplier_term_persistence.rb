# frozen_string_literal: true

class AddHotelSupplierTermPersistence < ActiveRecord::Migration[8.1]
  WORDING_LIMIT = 2_000

  def up
    add_column :supplier_cost_definitions, :commission_treatment, :string, null: false, default: "unspecified"
    add_check_constraint :supplier_cost_definitions,
      "commission_treatment IN ('unspecified', 'noncommissionable')",
      name: "supplier_cost_definitions_commission_treatment"
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.validate_supplier_cost_component() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE source_item uuid;
      DECLARE definition_mode text;
      DECLARE definition_treatment text;
      BEGIN
        SELECT s.arrangement_item_id, d.mode, d.commission_treatment
          INTO source_item, definition_mode, definition_treatment
          FROM supplier_cost_definitions d
          JOIN supplier_cost_sources s ON s.id = d.supplier_cost_source_id
         WHERE d.id = NEW.supplier_cost_definition_id;
        IF definition_mode <> 'calculated' THEN
          RAISE EXCEPTION 'zero-cost definitions cannot contain components';
        END IF;
        IF definition_treatment = 'noncommissionable' AND NEW.economic_role = 'expected_commission' THEN
          RAISE EXCEPTION 'noncommissionable definitions cannot contain expected commission';
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

      CREATE FUNCTION public.reject_noncommissionable_expected_commission() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.commission_treatment = 'noncommissionable' AND EXISTS (
          SELECT 1 FROM supplier_cost_components
           WHERE supplier_cost_definition_id = NEW.id
             AND economic_role = 'expected_commission'
        ) THEN
          RAISE EXCEPTION 'noncommissionable definitions cannot contain expected commission';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_cost_definitions_reject_noncommissionable_commission
        BEFORE INSERT OR UPDATE OF commission_treatment ON public.supplier_cost_definitions
        FOR EACH ROW EXECUTE FUNCTION public.reject_noncommissionable_expected_commission();

      CREATE FUNCTION public.reject_supplier_term_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE column_name text;
      BEGIN
        FOREACH column_name IN ARRAY TG_ARGV LOOP
          IF to_jsonb(NEW) ->> column_name IS DISTINCT FROM to_jsonb(OLD) ->> column_name THEN
            RAISE EXCEPTION '% owner is immutable', TG_TABLE_NAME;
          END IF;
        END LOOP;
        RETURN NEW;
      END;
      $$;

      CREATE FUNCTION public.validate_supplier_deposit_basis_totals() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE basis_id uuid;
      DECLARE basis_amount bigint;
      DECLARE basis_currency text;
      DECLARE entry_total bigint;
      DECLARE share_total integer;
      DECLARE mismatch boolean;
      BEGIN
        IF TG_TABLE_NAME = 'supplier_deposit_bases' AND TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;

        basis_id := CASE TG_TABLE_NAME
          WHEN 'supplier_deposit_bases' THEN NEW.id
          ELSE COALESCE(NEW.supplier_deposit_basis_id, OLD.supplier_deposit_basis_id)
        END;

        SELECT b.basis_amount_minor_units, b.currency
          INTO basis_amount, basis_currency
          FROM supplier_deposit_bases b
         WHERE b.id = basis_id;
        IF NOT FOUND THEN
          RETURN COALESCE(NEW, OLD);
        END IF;

        SELECT COALESCE(SUM(extended_amount_minor_units), 0)
          INTO entry_total
          FROM supplier_deposit_basis_entries
         WHERE supplier_deposit_basis_id = basis_id;
        IF entry_total IS DISTINCT FROM basis_amount THEN
          RAISE EXCEPTION 'deposit basis entries do not match the basis amount';
        END IF;

        SELECT COALESCE(SUM(share_basis_points), 0)
          INTO share_total
          FROM supplier_deposit_basis_shares
         WHERE supplier_deposit_basis_id = basis_id;
        IF share_total IS DISTINCT FROM 10000 THEN
          RAISE EXCEPTION 'deposit basis shares must total 10000 basis points';
        END IF;

        SELECT EXISTS (
          SELECT 1
            FROM supplier_deposit_basis_shares s
            JOIN supplier_deposit_requirement_definitions d
              ON d.id = s.supplier_deposit_requirement_definition_id
           WHERE s.supplier_deposit_basis_id = basis_id
             AND (
               d.amount_shape IS DISTINCT FROM 'fixed_amount'
               OR d.currency IS DISTINCT FROM basis_currency
               OR d.fixed_amount_minor_units IS NULL
               OR basis_amount * s.share_basis_points IS DISTINCT FROM d.fixed_amount_minor_units * 10000
             )
        ) INTO mismatch;
        IF mismatch THEN
          RAISE EXCEPTION 'deposit basis shares do not match the fixed requirements';
        END IF;

        RETURN COALESCE(NEW, OLD);
      END;
      $$;
    SQL

    create_basis_tables!
    create_attrition_tables!
    create_clarification_table!
    freeze_tables!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def create_basis_tables!
    create_table :supplier_deposit_bases, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :arrangement_item_id, null: false
      table.string :basis_kind, null: false
      table.string :currency, null: false, limit: 3
      table.bigint :basis_amount_minor_units, null: false
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    lineage_indexes(:supplier_deposit_bases, "deposit_bases")
    add_index :supplier_deposit_bases,
      [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_bases_on_child_owner"
    add_index :supplier_deposit_bases, [ :supplier_arrangement_version_id, :arrangement_item_id ],
      unique: true, name: "index_deposit_bases_on_version_and_item"
    version_and_item_fks(:supplier_deposit_bases, "deposit_bases")
    copied_from_fk(:supplier_deposit_bases, "deposit_bases")
    add_check_constraint :supplier_deposit_bases,
      "basis_kind = 'original_contracted_room_revenue'",
      name: "deposit_bases_kind"
    add_check_constraint :supplier_deposit_bases,
      "currency ~ '^[A-Z]{3}$'",
      name: "deposit_bases_currency"
    add_check_constraint :supplier_deposit_bases,
      "basis_amount_minor_units >= 0",
      name: "deposit_bases_amount"
    add_check_constraint :supplier_deposit_bases,
      "lock_version >= 0",
      name: "deposit_bases_lock_version"

    create_table :supplier_deposit_basis_entries, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_basis_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.integer :agreed_quantity, null: false
      table.bigint :agreed_unit_rate_minor_units, null: false
      table.bigint :extended_amount_minor_units, null: false
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    lineage_indexes(:supplier_deposit_basis_entries, "deposit_basis_entries")
    add_index :supplier_deposit_basis_entries,
      [ :supplier_deposit_basis_id, :service_occurrence_id, :supplier_resource_id ],
      unique: true, name: "index_deposit_basis_entries_on_line"
    add_foreign_key :supplier_deposit_basis_entries, :supplier_deposit_bases,
      column: [ :supplier_deposit_basis_id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_basis_entries_basis_fk"
    add_foreign_key :supplier_deposit_basis_entries, :service_occurrences,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_basis_entries_occurrence_fk"
    add_foreign_key :supplier_deposit_basis_entries, :supplier_resources,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_basis_entries_resource_fk"
    copied_from_fk(:supplier_deposit_basis_entries, "deposit_basis_entries")
    add_check_constraint :supplier_deposit_basis_entries,
      "agreed_quantity > 0 AND agreed_unit_rate_minor_units >= 0 AND extended_amount_minor_units >= 0 AND agreed_quantity * agreed_unit_rate_minor_units = extended_amount_minor_units",
      name: "deposit_basis_entries_extension"

    create_table :supplier_deposit_basis_shares, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :supplier_deposit_basis_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :supplier_deposit_requirement_definition_id, null: false
      table.integer :share_basis_points, null: false
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    lineage_indexes(:supplier_deposit_basis_shares, "deposit_basis_shares")
    add_index :supplier_deposit_basis_shares, :supplier_deposit_requirement_definition_id,
      unique: true, name: "index_deposit_basis_shares_on_requirement"
    add_foreign_key :supplier_deposit_basis_shares, :supplier_deposit_bases,
      column: [ :supplier_deposit_basis_id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_basis_shares_basis_fk"
    add_foreign_key :supplier_deposit_basis_shares, :supplier_deposit_requirement_definitions,
      column: [ :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_basis_shares_requirement_fk"
    copied_from_fk(:supplier_deposit_basis_shares, "deposit_basis_shares")
    add_check_constraint :supplier_deposit_basis_shares,
      "share_basis_points BETWEEN 1 AND 10000",
      name: "deposit_basis_shares_points"
  end

  def create_attrition_tables!
    create_table :hotel_attrition_policies, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :arrangement_item_id, null: false
      table.string :consequence, null: false
      table.integer :consequence_basis_points, null: false
      table.integer :quoted_tax_rate_basis_points, null: false
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    lineage_indexes(:hotel_attrition_policies, "attrition_policies")
    add_index :hotel_attrition_policies,
      [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_attrition_policies_on_child_owner"
    add_index :hotel_attrition_policies, [ :supplier_arrangement_version_id, :arrangement_item_id ],
      unique: true, name: "index_attrition_policies_on_version_and_item"
    version_and_item_fks(:hotel_attrition_policies, "attrition_policies")
    copied_from_fk(:hotel_attrition_policies, "attrition_policies")
    add_check_constraint :hotel_attrition_policies,
      "consequence = 'lost_room_revenue' AND consequence_basis_points = 10000",
      name: "attrition_policies_consequence"
    add_check_constraint :hotel_attrition_policies,
      "quoted_tax_rate_basis_points BETWEEN 0 AND 10000",
      name: "attrition_policies_tax_rate"
    add_check_constraint :hotel_attrition_policies,
      "lock_version >= 0",
      name: "attrition_policies_lock_version"

    create_table :hotel_attrition_nights, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :hotel_attrition_policy_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.integer :minimum_utilized_room_nights, null: false
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    lineage_indexes(:hotel_attrition_nights, "attrition_nights")
    add_index :hotel_attrition_nights, [ :hotel_attrition_policy_id, :service_occurrence_id ],
      unique: true, name: "index_attrition_nights_on_policy_and_occurrence"
    add_foreign_key :hotel_attrition_nights, :hotel_attrition_policies,
      column: [ :hotel_attrition_policy_id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "attrition_nights_policy_fk"
    add_foreign_key :hotel_attrition_nights, :service_occurrences,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "attrition_nights_occurrence_fk"
    copied_from_fk(:hotel_attrition_nights, "attrition_nights")
    add_check_constraint :hotel_attrition_nights,
      "minimum_utilized_room_nights > 0",
      name: "attrition_nights_minimum"

    create_table :hotel_attrition_zero_utilization_rates, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :hotel_attrition_policy_id, null: false
      table.uuid :arrangement_item_id, null: false
      table.uuid :supplier_resource_id, null: false
      table.bigint :amount_minor_units, null: false
      table.uuid :copied_from_id
      table.timestamps null: false
    end
    lineage_indexes(:hotel_attrition_zero_utilization_rates, "attrition_zero_rates")
    add_index :hotel_attrition_zero_utilization_rates, [ :hotel_attrition_policy_id, :supplier_resource_id ],
      unique: true, name: "index_attrition_zero_rates_on_policy_and_resource"
    add_foreign_key :hotel_attrition_zero_utilization_rates, :hotel_attrition_policies,
      column: [ :hotel_attrition_policy_id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "attrition_zero_rates_policy_fk"
    add_foreign_key :hotel_attrition_zero_utilization_rates, :supplier_resources,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "attrition_zero_rates_resource_fk"
    copied_from_fk(:hotel_attrition_zero_utilization_rates, "attrition_zero_rates")
    add_check_constraint :hotel_attrition_zero_utilization_rates,
      "amount_minor_units >= 0",
      name: "attrition_zero_rates_amount"
  end

  def create_clarification_table!
    create_table :supplier_deposit_refund_clarifications, id: :uuid, default: -> { "uuidv7()" } do |table|
      owner_columns(table)
      table.uuid :arrangement_item_id, null: false
      table.string :original_wording, null: false, limit: WORDING_LIMIT
      table.string :governing_wording, null: false, limit: WORDING_LIMIT
      table.string :payer, null: false
      table.string :recipient, null: false
      table.date :refund_due_on, null: false
      table.string :evidence_note, limit: WORDING_LIMIT
      table.uuid :recorded_by_id, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :copied_from_id
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    lineage_indexes(:supplier_deposit_refund_clarifications, "deposit_refund_clarifications")
    add_index :supplier_deposit_refund_clarifications, [ :supplier_arrangement_version_id, :arrangement_item_id ],
      unique: true, name: "index_deposit_refund_clarifications_on_version_item"
    version_and_item_fks(:supplier_deposit_refund_clarifications, "deposit_refund_clarifications")
    copied_from_fk(:supplier_deposit_refund_clarifications, "deposit_refund_clarifications")
    add_foreign_key :supplier_deposit_refund_clarifications, :agency_users,
      column: [ :recorded_by_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "deposit_refund_clarifications_recorder_fk"
    add_check_constraint :supplier_deposit_refund_clarifications,
      "payer = 'agency' AND recipient = 'agency'",
      name: "deposit_refund_clarifications_parties"
    add_check_constraint :supplier_deposit_refund_clarifications,
      "original_wording = btrim(original_wording) AND char_length(original_wording) BETWEEN 1 AND #{WORDING_LIMIT} AND governing_wording = btrim(governing_wording) AND char_length(governing_wording) BETWEEN 1 AND #{WORDING_LIMIT}",
      name: "deposit_refund_clarifications_wording"
    add_check_constraint :supplier_deposit_refund_clarifications,
      "evidence_note IS NULL OR (evidence_note = btrim(evidence_note) AND char_length(evidence_note) BETWEEN 1 AND #{WORDING_LIMIT})",
      name: "deposit_refund_clarifications_note"
    add_check_constraint :supplier_deposit_refund_clarifications,
      "lock_version >= 0",
      name: "deposit_refund_clarifications_lock_version"
  end

  def freeze_tables!
    {
      "supplier_deposit_bases" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id basis_kind copied_from_id],
      "supplier_deposit_basis_entries" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id supplier_deposit_basis_id arrangement_item_id service_occurrence_id supplier_resource_id copied_from_id],
      "supplier_deposit_basis_shares" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id supplier_deposit_basis_id arrangement_item_id supplier_deposit_requirement_definition_id copied_from_id],
      "hotel_attrition_policies" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id consequence consequence_basis_points copied_from_id],
      "hotel_attrition_nights" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id hotel_attrition_policy_id arrangement_item_id service_occurrence_id copied_from_id],
      "hotel_attrition_zero_utilization_rates" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id hotel_attrition_policy_id arrangement_item_id supplier_resource_id copied_from_id],
      "supplier_deposit_refund_clarifications" => %w[agency_id departure_id supplier_arrangement_id supplier_arrangement_version_id arrangement_item_id copied_from_id]
    }.each do |table_name, columns|
      execute <<~SQL
        CREATE TRIGGER #{table_name}_reject_non_draft
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table_name}
          FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();

        CREATE TRIGGER #{table_name}_reject_owner_change
          BEFORE UPDATE ON public.#{table_name}
          FOR EACH ROW EXECUTE FUNCTION reject_supplier_term_owner_change(#{columns.map { |column| "'#{column}'" }.join(", ")});
      SQL
    end

    execute <<~SQL
      CREATE CONSTRAINT TRIGGER supplier_deposit_bases_validate_totals
        AFTER INSERT OR UPDATE ON public.supplier_deposit_bases
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_deposit_basis_totals();

      CREATE CONSTRAINT TRIGGER supplier_deposit_basis_entries_validate_totals
        AFTER INSERT OR UPDATE OR DELETE ON public.supplier_deposit_basis_entries
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_deposit_basis_totals();

      CREATE CONSTRAINT TRIGGER supplier_deposit_basis_shares_validate_totals
        AFTER INSERT OR UPDATE OR DELETE ON public.supplier_deposit_basis_shares
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_deposit_basis_totals();
    SQL
  end

  def owner_columns(table)
    table.uuid :agency_id, null: false
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_arrangement_version_id, null: false
  end

  def lineage_indexes(table_name, prefix)
    add_index table_name, [ :id, :agency_id ], unique: true, name: "index_#{prefix}_on_id_agency"
    add_index table_name, [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_#{prefix}_on_lineage_owner"
    add_foreign_key table_name, :agencies
  end

  def version_and_item_fks(table_name, prefix)
    add_foreign_key table_name, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_version_fk"
    add_foreign_key table_name, :arrangement_items,
      column: [ :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_item_fk"
  end

  def copied_from_fk(table_name, prefix)
    add_foreign_key table_name, table_name,
      column: [ :copied_from_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix}_copied_from_fk"
  end
end
