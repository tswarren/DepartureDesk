class EnforceDeparturePartyRolePrimary < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION departure_party_role_assert_one_primary(target_departure_id uuid, target_role text) RETURNS void
      LANGUAGE plpgsql
      AS $$
      DECLARE
        current_count integer;
        primary_count integer;
      BEGIN
        SELECT COUNT(*)::integer,
               COUNT(*) FILTER (WHERE is_primary)::integer
          INTO current_count, primary_count
          FROM departure_party_role_assignments
          WHERE departure_id = target_departure_id
            AND role = target_role
            AND effective_until IS NULL;

        IF current_count > 0 AND primary_count <> 1 THEN
          RAISE EXCEPTION 'a role with current assignments must have exactly one primary'
            USING ERRCODE = 'check_violation';
        END IF;
      END;
      $$;

      CREATE FUNCTION departure_party_role_current_has_one_primary() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP <> 'DELETE' THEN
          PERFORM departure_party_role_assert_one_primary(NEW.departure_id, NEW.role);
        END IF;

        IF TG_OP = 'DELETE' OR (
          TG_OP = 'UPDATE'
          AND (
            OLD.departure_id IS DISTINCT FROM NEW.departure_id
            OR OLD.role IS DISTINCT FROM NEW.role
          )
        ) THEN
          PERFORM departure_party_role_assert_one_primary(OLD.departure_id, OLD.role);
        END IF;

        RETURN NULL;
      END;
      $$;

      CREATE CONSTRAINT TRIGGER dpra_current_role_has_one_primary
        AFTER INSERT OR UPDATE OR DELETE ON departure_party_role_assignments
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW
        EXECUTE FUNCTION departure_party_role_current_has_one_primary();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS dpra_current_role_has_one_primary ON departure_party_role_assignments;
      DROP FUNCTION IF EXISTS departure_party_role_current_has_one_primary();
      DROP FUNCTION IF EXISTS departure_party_role_assert_one_primary(uuid, text);
    SQL
  end
end
