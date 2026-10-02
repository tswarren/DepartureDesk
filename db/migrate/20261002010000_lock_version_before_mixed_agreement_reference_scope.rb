# frozen_string_literal: true

class LockVersionBeforeMixedAgreementReferenceScope < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.reject_mixed_agreement_reference_scope() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        -- Exclusive lock before the opposite-scope check. A shared lock lets two
        -- inserts of opposite scope both observe an empty set and both commit.
        -- Version, Item, and kind cannot move: reject_supplier_term_owner_change
        -- rejects that update, so only this version row needs the lock.
        PERFORM id
          FROM supplier_arrangement_versions
         WHERE id = NEW.supplier_arrangement_version_id
           FOR UPDATE;

        IF TG_OP = 'UPDATE'
           AND OLD.supplier_arrangement_version_id IS NOT DISTINCT FROM NEW.supplier_arrangement_version_id
           AND OLD.kind IS NOT DISTINCT FROM NEW.kind
           AND OLD.arrangement_item_id IS NOT DISTINCT FROM NEW.arrangement_item_id
        THEN
          RETURN NEW;
        END IF;

        IF EXISTS (
          SELECT 1
            FROM supplier_agreement_references existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND existing.id IS DISTINCT FROM NEW.id
             AND (existing.arrangement_item_id IS NULL) IS DISTINCT FROM (NEW.arrangement_item_id IS NULL)
        ) THEN
          RAISE EXCEPTION 'an agreement reference kind cannot use both Item scope and agreement-wide scope';
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER supplier_agreement_references_reject_mixed_scope ON public.supplier_agreement_references;
      CREATE TRIGGER supplier_agreement_references_guard_mixed_scope
        BEFORE INSERT OR UPDATE ON public.supplier_agreement_references
        FOR EACH ROW EXECUTE FUNCTION reject_mixed_agreement_reference_scope();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_agreement_references_guard_mixed_scope ON public.supplier_agreement_references;

      CREATE OR REPLACE FUNCTION public.reject_mixed_agreement_reference_scope() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE'
           AND OLD.supplier_arrangement_version_id IS NOT DISTINCT FROM NEW.supplier_arrangement_version_id
           AND OLD.kind IS NOT DISTINCT FROM NEW.kind
           AND OLD.arrangement_item_id IS NOT DISTINCT FROM NEW.arrangement_item_id
        THEN
          RETURN NEW;
        END IF;

        IF EXISTS (
          SELECT 1
            FROM supplier_agreement_references existing
           WHERE existing.supplier_arrangement_version_id = NEW.supplier_arrangement_version_id
             AND existing.kind = NEW.kind
             AND existing.id IS DISTINCT FROM NEW.id
             AND (existing.arrangement_item_id IS NULL) IS DISTINCT FROM (NEW.arrangement_item_id IS NULL)
        ) THEN
          RAISE EXCEPTION 'an agreement reference kind cannot use both Item scope and agreement-wide scope';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_agreement_references_reject_mixed_scope
        BEFORE INSERT OR UPDATE ON public.supplier_agreement_references
        FOR EACH ROW EXECUTE FUNCTION reject_mixed_agreement_reference_scope();
    SQL
  end
end
