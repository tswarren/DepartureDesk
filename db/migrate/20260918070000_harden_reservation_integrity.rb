# frozen_string_literal: true

class HardenReservationIntegrity < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_reservation_scope_without_capacity_pool_definition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.target_kind IS DISTINCT FROM 'capacity_pool' THEN
          RETURN NEW;
        END IF;

        IF NOT EXISTS (
          SELECT 1
          FROM public.capacity_pool_definitions definitions
          WHERE definitions.agency_id = NEW.agency_id
            AND definitions.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
            AND definitions.capacity_pool_id = NEW.capacity_pool_id
        ) THEN
          RAISE EXCEPTION 'reservation capacity pool scope requires a version definition';
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_reservation_scopes_require_pool_definition
        ON public.supplier_reservation_scopes;
      CREATE TRIGGER supplier_reservation_scopes_require_pool_definition
        BEFORE INSERT OR UPDATE ON public.supplier_reservation_scopes
        FOR EACH ROW EXECUTE FUNCTION reject_reservation_scope_without_capacity_pool_definition();
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_incompatible_reservation_outcome() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        parent_event_kind text;
        allowed boolean := false;
      BEGIN
        SELECT event_kind INTO parent_event_kind
        FROM public.supplier_reservation_events
        WHERE id = NEW.supplier_reservation_event_id;

        IF parent_event_kind IS NULL THEN
          RAISE EXCEPTION 'reservation outcome requires a parent event';
        END IF;

        IF parent_event_kind = 'request' AND NEW.outcome_kind = 'requested' THEN
          allowed := true;
        ELSIF parent_event_kind = 'withdrawal' AND NEW.outcome_kind = 'withdrawn' THEN
          allowed := true;
        ELSIF parent_event_kind = 'cancellation' AND NEW.outcome_kind = 'cancelled' THEN
          allowed := true;
        ELSIF parent_event_kind = 'response'
          AND NEW.outcome_kind IN ('confirmed', 'declined', 'counterproposed') THEN
          allowed := true;
        END IF;

        IF NOT allowed THEN
          RAISE EXCEPTION 'reservation outcome kind is incompatible with parent event kind';
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_reservation_outcomes_require_event_compat
        ON public.supplier_reservation_event_scope_outcomes;
      CREATE TRIGGER supplier_reservation_outcomes_require_event_compat
        BEFORE INSERT ON public.supplier_reservation_event_scope_outcomes
        FOR EACH ROW EXECUTE FUNCTION reject_incompatible_reservation_outcome();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_reservation_outcomes_require_event_compat
        ON public.supplier_reservation_event_scope_outcomes;
      DROP FUNCTION IF EXISTS reject_incompatible_reservation_outcome();

      DROP TRIGGER IF EXISTS supplier_reservation_scopes_require_pool_definition
        ON public.supplier_reservation_scopes;
      DROP FUNCTION IF EXISTS reject_reservation_scope_without_capacity_pool_definition();
    SQL
  end
end
