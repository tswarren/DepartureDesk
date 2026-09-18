class StampSupersededIdentifierOnSuccessorInsert < ActiveRecord::Migration[8.1]
  def up
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
          AND superseded_at IS NULL;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'supplier identifier supersession target is missing or already superseded';
        END IF;

        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS supplier_issued_identifiers_stamp_superseded ON public.supplier_issued_identifiers;
      CREATE TRIGGER supplier_issued_identifiers_stamp_superseded
        AFTER INSERT ON public.supplier_issued_identifiers
        FOR EACH ROW
        WHEN (NEW.supersedes_id IS NOT NULL)
        EXECUTE FUNCTION stamp_supplier_identifier_superseded_by_successor();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_issued_identifiers_stamp_superseded ON public.supplier_issued_identifiers;
      DROP FUNCTION IF EXISTS stamp_supplier_identifier_superseded_by_successor();
    SQL
  end
end
