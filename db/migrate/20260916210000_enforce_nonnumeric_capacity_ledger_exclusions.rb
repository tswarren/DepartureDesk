class EnforceNonnumericCapacityLedgerExclusions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION reject_nonnumeric_capacity_pool_definition_quantity() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        pool_mode text;
      BEGIN
        SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
        IF pool_mode IN ('on_request', 'externally_managed') AND NEW.proposed_opening_quantity IS NOT NULL THEN
          RAISE EXCEPTION 'nonnumeric capacity pools cannot store a proposed opening quantity';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_pool_definitions_reject_nonnumeric_quantity
      BEFORE INSERT OR UPDATE ON capacity_pool_definitions
      FOR EACH ROW EXECUTE FUNCTION reject_nonnumeric_capacity_pool_definition_quantity();

      CREATE FUNCTION reject_nonnumeric_capacity_event() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        pool_mode text;
      BEGIN
        SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
        IF pool_mode IN ('on_request', 'externally_managed') THEN
          RAISE EXCEPTION 'nonnumeric capacity pools cannot store capacity events';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_events_reject_nonnumeric_pool
      BEFORE INSERT ON capacity_events
      FOR EACH ROW EXECUTE FUNCTION reject_nonnumeric_capacity_event();

      CREATE FUNCTION reject_nonnumeric_capacity_projection() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        pool_mode text;
      BEGIN
        SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
        IF pool_mode IN ('on_request', 'externally_managed') THEN
          RAISE EXCEPTION 'nonnumeric capacity pools cannot store projections';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_projections_reject_nonnumeric_pool
      BEFORE INSERT ON capacity_projections
      FOR EACH ROW EXECUTE FUNCTION reject_nonnumeric_capacity_projection();

      CREATE FUNCTION reject_nonnumeric_capacity_reconciliation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        pool_mode text;
      BEGIN
        SELECT inventory_mode INTO pool_mode FROM capacity_pools WHERE id = NEW.capacity_pool_id;
        IF pool_mode IN ('on_request', 'externally_managed') THEN
          RAISE EXCEPTION 'nonnumeric capacity pools cannot store reconciliations';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER capacity_reconciliations_reject_nonnumeric_pool
      BEFORE INSERT ON capacity_reconciliations
      FOR EACH ROW EXECUTE FUNCTION reject_nonnumeric_capacity_reconciliation();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS capacity_pool_definitions_reject_nonnumeric_quantity ON capacity_pool_definitions;
      DROP TRIGGER IF EXISTS capacity_events_reject_nonnumeric_pool ON capacity_events;
      DROP TRIGGER IF EXISTS capacity_projections_reject_nonnumeric_pool ON capacity_projections;
      DROP TRIGGER IF EXISTS capacity_reconciliations_reject_nonnumeric_pool ON capacity_reconciliations;
      DROP FUNCTION IF EXISTS reject_nonnumeric_capacity_pool_definition_quantity();
      DROP FUNCTION IF EXISTS reject_nonnumeric_capacity_event();
      DROP FUNCTION IF EXISTS reject_nonnumeric_capacity_projection();
      DROP FUNCTION IF EXISTS reject_nonnumeric_capacity_reconciliation();
    SQL
  end
end
