# frozen_string_literal: true

class HardenScopeInsertAndIdentifierSupersessionOwners < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_requested_reservation_scope_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        revision_status text;
        revision_id uuid;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          revision_id := NEW.supplier_reservation_revision_id;
        ELSE
          revision_id := OLD.supplier_reservation_revision_id;
        END IF;

        SELECT status INTO revision_status
        FROM supplier_reservation_revisions
        WHERE id = revision_id;

        IF revision_status IS DISTINCT FROM 'planned' THEN
          RAISE EXCEPTION 'requested reservation scopes are immutable';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_reservation_scopes_freeze_after_request
        ON public.supplier_reservation_scopes;
      CREATE TRIGGER supplier_reservation_scopes_freeze_after_request
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_reservation_scopes
        FOR EACH ROW EXECUTE FUNCTION reject_requested_reservation_scope_mutation();
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION allow_supplier_identifier_supersession_stamp() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.superseded_at IS NULL
          AND NEW.superseded_at IS NOT NULL
          AND NEW.id IS NOT DISTINCT FROM OLD.id
          AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
          AND NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
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
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION stamp_supplier_identifier_superseded_by_successor() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.supersedes_id IS NULL THEN
          RETURN NEW;
        END IF;

        UPDATE public.supplier_issued_identifiers
        SET superseded_at = COALESCE(NEW.created_at, CURRENT_TIMESTAMP)
        WHERE id = NEW.supersedes_id
          AND agency_id = NEW.agency_id
          AND departure_id = NEW.departure_id
          AND supplier_arrangement_id = NEW.supplier_arrangement_id
          AND supplier_id = NEW.supplier_id
          AND supplier_reservation_id IS NOT DISTINCT FROM NEW.supplier_reservation_id
          AND superseded_at IS NULL;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'supplier identifier supersession target is missing, already superseded, or ownership differs';
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_issued_identifiers_stamp_superseded
        ON public.supplier_issued_identifiers;
      CREATE TRIGGER supplier_issued_identifiers_stamp_superseded
        BEFORE INSERT ON public.supplier_issued_identifiers
        FOR EACH ROW
        WHEN (NEW.supersedes_id IS NOT NULL)
        EXECUTE FUNCTION stamp_supplier_identifier_superseded_by_successor();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_issued_identifiers_stamp_superseded
        ON public.supplier_issued_identifiers;
      CREATE TRIGGER supplier_issued_identifiers_stamp_superseded
        AFTER INSERT ON public.supplier_issued_identifiers
        FOR EACH ROW
        WHEN (NEW.supersedes_id IS NOT NULL)
        EXECUTE FUNCTION stamp_supplier_identifier_superseded_by_successor();

      CREATE OR REPLACE FUNCTION stamp_supplier_identifier_superseded_by_successor() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.supersedes_id IS NULL THEN
          RETURN NEW;
        END IF;

        UPDATE public.supplier_issued_identifiers
        SET superseded_at = COALESCE(NEW.created_at, CURRENT_TIMESTAMP)
        WHERE id = NEW.supersedes_id
          AND agency_id = NEW.agency_id
          AND superseded_at IS NULL;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'supplier identifier supersession target is missing or already superseded';
        END IF;

        RETURN NEW;
      END;
      $$;
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
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_requested_reservation_scope_mutation() RETURNS trigger
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

      DROP TRIGGER IF EXISTS supplier_reservation_scopes_freeze_after_request
        ON public.supplier_reservation_scopes;
      CREATE TRIGGER supplier_reservation_scopes_freeze_after_request
        BEFORE UPDATE OR DELETE ON public.supplier_reservation_scopes
        FOR EACH ROW EXECUTE FUNCTION reject_requested_reservation_scope_mutation();
    SQL
  end
end
