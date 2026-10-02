# frozen_string_literal: true

class FreezeAgreementReferencesAfterSupplierConfirmation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION public.reject_confirmed_agreement_reference_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE version_id uuid;
      BEGIN
        version_id := CASE TG_OP
          WHEN 'DELETE' THEN OLD.supplier_arrangement_version_id
          ELSE NEW.supplier_arrangement_version_id
        END;

        PERFORM id
          FROM supplier_arrangement_versions
         WHERE id = version_id
           FOR SHARE;

        IF EXISTS (
          SELECT 1
            FROM supplier_confirmations
           WHERE supplier_arrangement_version_id = version_id
        ) THEN
          RAISE EXCEPTION 'agreement references are immutable after Supplier confirmation';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_agreement_references_reject_confirmed
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_agreement_references
        FOR EACH ROW EXECUTE FUNCTION reject_confirmed_agreement_reference_mutation();

      CREATE FUNCTION public.lock_version_before_supplier_confirmation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM id
          FROM supplier_arrangement_versions
         WHERE id = NEW.supplier_arrangement_version_id
           FOR UPDATE;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_confirmations_lock_version
        BEFORE INSERT ON public.supplier_confirmations
        FOR EACH ROW EXECUTE FUNCTION lock_version_before_supplier_confirmation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
