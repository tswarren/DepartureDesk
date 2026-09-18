class HardenM3dReservationScopeAndIdentifierSupersession < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DROP INDEX IF EXISTS index_reservation_scopes_on_target;
      CREATE UNIQUE INDEX index_reservation_scopes_on_target
        ON public.supplier_reservation_scopes
        USING btree (
          supplier_reservation_revision_id,
          target_kind,
          arrangement_item_id,
          service_occurrence_id,
          supplier_resource_id,
          capacity_pool_id
        )
        NULLS NOT DISTINCT;
    SQL

    execute <<~SQL
      CREATE FUNCTION reject_requested_reservation_scope_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        revision_status text;
      BEGIN
        SELECT status INTO revision_status
        FROM supplier_reservation_revisions
        WHERE id = OLD.supplier_reservation_revision_id;

        IF revision_status IS DISTINCT FROM 'planned' THEN
          RAISE EXCEPTION 'requested reservation scopes are immutable';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_reservation_scopes_freeze_after_request
        BEFORE UPDATE OR DELETE ON public.supplier_reservation_scopes
        FOR EACH ROW EXECUTE FUNCTION reject_requested_reservation_scope_mutation();
    SQL

    remove_check_constraint :supplier_issued_identifiers, name: "supplier_identifiers_supersession_pair"
    add_check_constraint :supplier_issued_identifiers, <<~SQL.squish, name: "supplier_identifiers_supersession_pair"
      (superseded_at IS NULL) OR (supersedes_id IS NULL)
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION allow_supplier_identifier_supersession_stamp() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.superseded_at IS NULL
          AND NEW.superseded_at IS NOT NULL
          AND NEW.supersedes_id IS NOT DISTINCT FROM OLD.supersedes_id
          AND NEW.agency_id IS NOT DISTINCT FROM OLD.agency_id
          AND NEW.departure_id IS NOT DISTINCT FROM OLD.departure_id
          AND NEW.supplier_arrangement_id IS NOT DISTINCT FROM OLD.supplier_arrangement_id
          AND NEW.supplier_reservation_id IS NOT DISTINCT FROM OLD.supplier_reservation_id
          AND NEW.supplier_id IS NOT DISTINCT FROM OLD.supplier_id
          AND NEW.issuer_context IS NOT DISTINCT FROM OLD.issuer_context
          AND NEW.identifier_type IS NOT DISTINCT FROM OLD.identifier_type
          AND NEW.other_type_label IS NOT DISTINCT FROM OLD.other_type_label
          AND NEW.display_value IS NOT DISTINCT FROM OLD.display_value
          AND NEW.normalized_value IS NOT DISTINCT FROM OLD.normalized_value
          AND NEW.first_supplier_confirmation_id IS NOT DISTINCT FROM OLD.first_supplier_confirmation_id
        THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'supplier_issued_identifiers is append-only';
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_issued_identifiers_reject_update ON public.supplier_issued_identifiers;
      CREATE TRIGGER supplier_issued_identifiers_reject_update
        BEFORE UPDATE ON public.supplier_issued_identifiers
        FOR EACH ROW EXECUTE FUNCTION allow_supplier_identifier_supersession_stamp();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_issued_identifiers_reject_update ON public.supplier_issued_identifiers;
      CREATE TRIGGER supplier_issued_identifiers_reject_update
        BEFORE UPDATE ON public.supplier_issued_identifiers
        FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      DROP FUNCTION IF EXISTS allow_supplier_identifier_supersession_stamp();
    SQL

    remove_check_constraint :supplier_issued_identifiers, name: "supplier_identifiers_supersession_pair"
    add_check_constraint :supplier_issued_identifiers, <<~SQL.squish, name: "supplier_identifiers_supersession_pair"
      (supersedes_id IS NULL) = (superseded_at IS NULL)
    SQL

    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_reservation_scopes_freeze_after_request ON public.supplier_reservation_scopes;
      DROP FUNCTION IF EXISTS reject_requested_reservation_scope_mutation();
      DROP INDEX IF EXISTS index_reservation_scopes_on_target;
      CREATE UNIQUE INDEX index_reservation_scopes_on_target
        ON public.supplier_reservation_scopes
        USING btree (
          supplier_reservation_revision_id,
          target_kind,
          arrangement_item_id,
          service_occurrence_id,
          supplier_resource_id,
          capacity_pool_id
        );
    SQL
  end
end
