class LockExternalIdentifierNormalizedValueAndSource < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION external_identifiers_prevent_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.party_id IS DISTINCT FROM OLD.party_id
          OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
          OR NEW.supplier_profile_id IS DISTINCT FROM OLD.supplier_profile_id
          OR NEW.identifier_type IS DISTINCT FROM OLD.identifier_type
          OR NEW.issuer IS DISTINCT FROM OLD.issuer
          OR NEW.original_value IS DISTINCT FROM OLD.original_value
          OR NEW.normalized_value IS DISTINCT FROM OLD.normalized_value
          OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version
          OR NEW.source IS DISTINCT FROM OLD.source THEN
          RAISE EXCEPTION 'external identifier identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION external_identifiers_prevent_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.party_id IS DISTINCT FROM OLD.party_id
          OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
          OR NEW.supplier_profile_id IS DISTINCT FROM OLD.supplier_profile_id
          OR NEW.identifier_type IS DISTINCT FROM OLD.identifier_type
          OR NEW.issuer IS DISTINCT FROM OLD.issuer
          OR NEW.original_value IS DISTINCT FROM OLD.original_value
          OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version THEN
          RAISE EXCEPTION 'external identifier identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end
end
