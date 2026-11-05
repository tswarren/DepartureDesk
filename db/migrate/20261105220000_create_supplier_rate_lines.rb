# frozen_string_literal: true

# Slice 1 step 3a (SUP-35, D-75, ADR 0018): an arrangement's supplier rate
# table, one row per inventory group, occupancy position and optional
# traveler type, with the components staff enter. Rows are edited while the
# arrangement is Draft and frozen once it leaves Draft.
class CreateSupplierRateLines < ActiveRecord::Migration[8.1]
  def up
    add_index :inventory_groups, %i[id supplier_arrangement_id], unique: true, name: "index_inventory_groups_on_id_and_arrangement"
    add_index :supplier_arrangements, %i[id currency], unique: true, name: "index_supplier_arrangements_on_id_and_currency"

    create_table :supplier_rate_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :inventory_group_id, null: false
      table.uuid :traveler_type_id
      table.string :occupancy_position, null: false
      table.string :currency, null: false
      table.bigint :base_fare_minor_units, null: false
      table.bigint :non_commissionable_fees_minor_units, null: false, default: 0
      table.bigint :taxes_minor_units, null: false, default: 0
      table.bigint :discount_minor_units, null: false, default: 0
      table.decimal :commission_rate, precision: 6, scale: 3
      table.bigint :commission_minor_units
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :supplier_arrangement_id, name: "index_supplier_rate_lines_on_arrangement"
      table.index %i[inventory_group_id occupancy_position traveler_type_id], unique: true, nulls_not_distinct: true,
        name: "index_supplier_rate_lines_one_per_group_position_type"
      table.check_constraint "occupancy_position = 'single' OR occupancy_position ~ '^guest_[1-9]$'", name: "supplier_rate_lines_occupancy_position"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "supplier_rate_lines_currency"
      table.check_constraint <<~SQL.squish, name: "supplier_rate_lines_amounts_non_negative"
        base_fare_minor_units >= 0 AND non_commissionable_fees_minor_units >= 0 AND taxes_minor_units >= 0
        AND discount_minor_units >= 0 AND (commission_minor_units IS NULL OR commission_minor_units >= 0)
      SQL
      table.check_constraint "commission_rate IS NULL OR (commission_rate >= 0 AND commission_rate <= 100)", name: "supplier_rate_lines_commission_rate"
      table.check_constraint "commission_rate IS NULL OR commission_minor_units IS NULL", name: "supplier_rate_lines_commission_rate_or_amount"
      table.check_constraint "lock_version >= 0", name: "supplier_rate_lines_lock_version"
    end
    execute <<~SQL
      ALTER TABLE supplier_rate_lines
        ADD CONSTRAINT fk_supplier_rate_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_rate_lines_arrangement_same_agency
        FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_supplier_rate_lines_arrangement_currency
        FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES supplier_arrangements (id, currency),
        ADD CONSTRAINT fk_supplier_rate_lines_group_of_arrangement
        FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES inventory_groups (id, supplier_arrangement_id),
        ADD CONSTRAINT fk_supplier_rate_lines_traveler_type_same_agency
        FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);
    SQL

    execute <<~SQL
      -- SUP-35, ADR 0018: rows freeze when the arrangement leaves Draft. An
      -- effective-dated replacement row comes with the first case that changes a rate.
      CREATE FUNCTION public.reject_frozen_supplier_rate_line_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      DECLARE
        arrangement_status text;
      BEGIN
        IF TG_OP = 'UPDATE' AND (NEW.agency_id IS DISTINCT FROM OLD.agency_id
            OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id
            OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id) THEN
          RAISE EXCEPTION 'supplier rate line ownership is immutable';
        END IF;
        SELECT status INTO arrangement_status FROM supplier_arrangements
          WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.supplier_arrangement_id ELSE OLD.supplier_arrangement_id END;
        IF arrangement_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'supplier rate lines are frozen once the arrangement leaves draft';
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$;
      CREATE TRIGGER supplier_rate_lines_reject_frozen_change BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_rate_lines
        FOR EACH ROW EXECUTE FUNCTION public.reject_frozen_supplier_rate_line_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
