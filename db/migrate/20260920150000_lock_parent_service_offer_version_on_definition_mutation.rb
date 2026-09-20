# frozen_string_literal: true

class LockParentServiceOfferVersionOnDefinitionMutation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_non_draft_service_offer_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.service_offer_version_id;
        ELSE
          version_id := OLD.service_offer_version_id;
        END IF;

        -- Serialize against discard: wait for a concurrent version lock, then
        -- re-check status so a child edit cannot commit after draft → abandoned.
        SELECT status INTO version_status
        FROM public.service_offer_versions
        WHERE id = version_id
        FOR SHARE;

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
      CREATE OR REPLACE FUNCTION reject_non_draft_service_offer_version_definition_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
        version_status text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          version_id := NEW.service_offer_version_id;
        ELSE
          version_id := OLD.service_offer_version_id;
        END IF;

        SELECT status INTO version_status
        FROM public.service_offer_versions
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
