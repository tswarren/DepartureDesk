class HardenSupplierCostDefinitionInvariants < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION reject_supplier_cost_definition_stage_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.stage IS DISTINCT FROM OLD.stage THEN
          RAISE EXCEPTION 'supplier cost definition stage is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_cost_definitions_reject_stage_change
        BEFORE UPDATE OF stage ON supplier_cost_definitions
        FOR EACH ROW EXECUTE FUNCTION reject_supplier_cost_definition_stage_change();

      CREATE FUNCTION validate_supplier_cost_definition_mode_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.mode = 'zero_cost' AND OLD.mode IS DISTINCT FROM 'zero_cost' AND EXISTS (
          SELECT 1 FROM supplier_cost_components c
           WHERE c.supplier_cost_definition_id = NEW.id
        ) THEN
          RAISE EXCEPTION 'zero-cost definitions cannot retain components';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_cost_definitions_validate_mode_change
        BEFORE UPDATE OF mode ON supplier_cost_definitions
        FOR EACH ROW EXECUTE FUNCTION validate_supplier_cost_definition_mode_change();

      CREATE FUNCTION clear_supplier_cost_component_bases_for_kind() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND NEW.calculation_kind IS DISTINCT FROM OLD.calculation_kind AND
           NEW.calculation_kind IN ('fixed', 'unit_rate') THEN
          DELETE FROM supplier_cost_component_bases
           WHERE supplier_cost_component_id = NEW.id;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_cost_components_clear_bases_for_kind
        AFTER UPDATE OF calculation_kind ON supplier_cost_components
        FOR EACH ROW EXECUTE FUNCTION clear_supplier_cost_component_bases_for_kind();

      CREATE OR REPLACE FUNCTION validate_supplier_cost_component_base() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE component_position integer;
      DECLARE component_kind text;
      DECLARE component_basis text;
      DECLARE component_category uuid;
      DECLARE component_from integer;
      DECLARE component_to integer;
      DECLARE base_position integer;
      DECLARE base_kind text;
      DECLARE base_basis text;
      DECLARE base_category uuid;
      DECLARE base_from integer;
      DECLARE base_to integer;
      BEGIN
        SELECT position, calculation_kind, quantity_basis, participant_category_id,
               occupancy_position_from, occupancy_position_to
          INTO component_position, component_kind, component_basis, component_category,
               component_from, component_to
          FROM supplier_cost_components
         WHERE id = NEW.supplier_cost_component_id
           AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
        SELECT position, calculation_kind, quantity_basis, participant_category_id,
               occupancy_position_from, occupancy_position_to
          INTO base_position, base_kind, base_basis, base_category, base_from, base_to
          FROM supplier_cost_components
         WHERE id = NEW.base_component_id
           AND supplier_cost_definition_id = NEW.supplier_cost_definition_id;
        IF component_position IS NULL OR base_position IS NULL OR base_position >= component_position THEN
          RAISE EXCEPTION 'cost component base must be an earlier component in the same definition';
        END IF;
        IF component_kind NOT IN ('percentage', 'minimum_amount_shortfall', 'minimum_quantity_shortfall') THEN
          RAISE EXCEPTION 'cost component kind does not accept bases';
        END IF;
        IF component_kind = 'minimum_quantity_shortfall' AND
           (base_kind <> 'unit_rate' OR NEW.direction <> 'add') THEN
          RAISE EXCEPTION 'quantity minimum base must be one earlier unit rate';
        END IF;
        IF component_kind = 'minimum_quantity_shortfall' AND (
             component_basis IS DISTINCT FROM base_basis
          OR component_category IS DISTINCT FROM base_category
          OR component_from IS DISTINCT FROM base_from
          OR component_to IS DISTINCT FROM base_to
        ) THEN
          RAISE EXCEPTION 'quantity minimum base selectors must match the unit rate';
        END IF;
        IF component_kind = 'minimum_quantity_shortfall' AND EXISTS (
          SELECT 1 FROM supplier_cost_component_bases
           WHERE supplier_cost_component_id = NEW.supplier_cost_component_id
             AND id <> NEW.id
        ) THEN
          RAISE EXCEPTION 'quantity minimum accepts exactly one base';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_cost_definitions_reject_stage_change ON supplier_cost_definitions;
      DROP FUNCTION IF EXISTS reject_supplier_cost_definition_stage_change();
      DROP TRIGGER IF EXISTS supplier_cost_definitions_validate_mode_change ON supplier_cost_definitions;
      DROP FUNCTION IF EXISTS validate_supplier_cost_definition_mode_change();
      DROP TRIGGER IF EXISTS supplier_cost_components_clear_bases_for_kind ON supplier_cost_components;
      DROP FUNCTION IF EXISTS clear_supplier_cost_component_bases_for_kind();
    SQL
  end
end
