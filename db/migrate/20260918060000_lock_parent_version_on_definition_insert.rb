# frozen_string_literal: true

class LockParentVersionOnDefinitionInsert < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_non_draft_arrangement_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.supplier_arrangement_version_id;
          -- Serialize against activation: either finish before activation reads the
          -- graph, or wait and re-check status after activation commits. UPDATE and
          -- DELETE already serialize on existing definition-row locks held by
          -- activation.
          SELECT status INTO version_status
          FROM public.supplier_arrangement_versions
          WHERE id = version_id
          FOR SHARE;
        ELSE
          version_id := OLD.supplier_arrangement_version_id;
          SELECT status INTO version_status
          FROM public.supplier_arrangement_versions
          WHERE id = version_id;
        END IF;

        IF version_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'exact-version definitions are immutable after leaving draft';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_non_draft_arrangement_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.supplier_arrangement_version_id;
        ELSE
          version_id := OLD.supplier_arrangement_version_id;
        END IF;

        SELECT status INTO version_status
        FROM public.supplier_arrangement_versions
        WHERE id = version_id;

        IF version_status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'exact-version definitions are immutable after leaving draft';
        END IF;

        IF TG_OP = 'DELETE' THEN
          RETURN OLD;
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end
end
