# frozen_string_literal: true

# The supplier rate grid (S-14, SUP-35; the walkthrough's rate entry
# finding). An arrangement's rate table now has a pricing pattern: bands,
# each a set of occupancy positions for any traveler or one traveler type,
# and values that apply to every fare unless a fare overrides them. The
# grid still saves into supplier_rate_lines, one per position and type, so
# the booking cost proposal and the freeze at confirmation are unchanged.
class CreateSupplierRateBands < ActiveRecord::Migration[8.1]
  POSITIONS = [ "single", *(1..9).map { |n| "guest_#{n}" } ].freeze

  def up
    add_column :supplier_arrangements, :rate_pattern, :string
    add_column :supplier_arrangements, :rate_non_commissionable_fees_minor_units, :bigint
    add_column :supplier_arrangements, :rate_taxes_minor_units, :bigint
    add_column :supplier_arrangements, :rate_commission_method, :string
    add_column :supplier_arrangements, :rate_commission_rate, :decimal, precision: 6, scale: 3
    add_column :supplier_arrangements, :rate_commission_base, :string
    add_column :supplier_arrangements, :rate_commission_minor_units, :bigint
    add_check_constraint :supplier_arrangements, "rate_pattern IS NULL OR rate_pattern IN ('cruise_bands', 'per_guest', 'per_room', 'custom')",
      name: "supplier_arrangements_rate_pattern"
    add_check_constraint :supplier_arrangements,
      "COALESCE(rate_non_commissionable_fees_minor_units, 0) >= 0 AND COALESCE(rate_taxes_minor_units, 0) >= 0 AND COALESCE(rate_commission_minor_units, 0) >= 0",
      name: "supplier_arrangements_rate_amounts"
    # A percentage carries its rate and what it applies to; a dollar amount only the amount.
    add_check_constraint :supplier_arrangements, <<~SQL.squish, name: "supplier_arrangements_rate_commission"
      COALESCE(
        (rate_commission_method IS NULL AND rate_commission_rate IS NULL AND rate_commission_base IS NULL AND rate_commission_minor_units IS NULL)
        OR (rate_commission_method = 'percent' AND rate_commission_rate >= 0 AND rate_commission_rate <= 100
            AND rate_commission_base IN ('base_fare', 'base_fare_less_discount') AND rate_commission_minor_units IS NULL)
        OR (rate_commission_method = 'amount' AND rate_commission_minor_units IS NOT NULL AND rate_commission_rate IS NULL AND rate_commission_base IS NULL),
        false)
    SQL

    create_table :supplier_rate_bands, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.string :label, null: false
      table.string :positions, array: true, null: false
      table.uuid :traveler_type_id
      table.integer :position, null: false, default: 0
      table.timestamps

      table.index %i[supplier_arrangement_id position], name: "index_supplier_rate_bands_on_arrangement_and_position"
      table.index %i[id agency_id], unique: true, name: "index_supplier_rate_bands_on_id_and_agency_id"
      table.check_constraint "btrim(label) <> '' AND char_length(label) <= 60", name: "supplier_rate_bands_label"
      table.check_constraint "cardinality(positions) >= 1 AND positions <@ ARRAY[#{POSITIONS.map { |p| quote(p) }.join(", ")}]::varchar[]",
        name: "supplier_rate_bands_positions"
      table.check_constraint "position >= 0", name: "supplier_rate_bands_position"
    end

    add_column :supplier_rate_lines, :supplier_rate_band_id, :uuid
    add_column :supplier_rate_lines, :overridden_fields, :string, array: true, null: false, default: []
    add_index :supplier_rate_lines, :supplier_rate_band_id, name: "index_supplier_rate_lines_on_band"
    add_check_constraint :supplier_rate_lines, "overridden_fields <@ ARRAY['non_commissionable_fees', 'taxes', 'commission']::varchar[]",
      name: "supplier_rate_lines_overridden_fields"

    execute <<~SQL
      ALTER TABLE supplier_rate_bands
        ADD CONSTRAINT fk_supplier_rate_bands_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_rate_bands_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_supplier_rate_bands_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);
      ALTER TABLE supplier_rate_lines
        ADD CONSTRAINT fk_supplier_rate_lines_band_same_agency FOREIGN KEY (supplier_rate_band_id, agency_id) REFERENCES supplier_rate_bands (id, agency_id);

      -- ADR 0018: the pattern is frozen with the rate table once the arrangement leaves draft.
      CREATE FUNCTION public.reject_frozen_supplier_rate_band_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      DECLARE
        arrangement_status text;
      BEGIN
        IF TG_OP = 'UPDATE' AND (NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.supplier_arrangement_id IS DISTINCT FROM OLD.supplier_arrangement_id) THEN
          RAISE EXCEPTION 'supplier rate band ownership is immutable';
        END IF;
        SELECT status INTO arrangement_status FROM supplier_arrangements
          WHERE id = CASE WHEN TG_OP = 'INSERT' THEN NEW.supplier_arrangement_id ELSE OLD.supplier_arrangement_id END;
        IF arrangement_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'supplier rate bands are frozen once the arrangement leaves draft';
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$;
      CREATE TRIGGER supplier_rate_bands_reject_frozen_change BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_rate_bands
        FOR EACH ROW EXECUTE FUNCTION public.reject_frozen_supplier_rate_band_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
