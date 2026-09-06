class EnforceClientAdvisorPointerHistoryAgreement < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION client_advisor_current_matches_open_assignment() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        target_profile_id uuid;
        pointer uuid;
        open_count integer;
        open_membership_id uuid;
      BEGIN
        IF TG_TABLE_NAME = 'client_profiles' THEN
          target_profile_id := COALESCE(NEW.id, OLD.id);
        ELSE
          target_profile_id := COALESCE(NEW.client_profile_id, OLD.client_profile_id);
        END IF;

        SELECT primary_advisor_membership_id
          INTO pointer
          FROM client_profiles
          WHERE id = target_profile_id;

        IF NOT FOUND THEN
          RETURN NULL;
        END IF;

        SELECT COUNT(*)::integer
          INTO open_count
          FROM client_advisor_assignments
          WHERE client_profile_id = target_profile_id
            AND effective_until IS NULL;

        IF pointer IS NULL THEN
          IF COALESCE(open_count, 0) <> 0 THEN
            RAISE EXCEPTION 'current advisor must agree with open assignment history'
              USING ERRCODE = 'check_violation';
          END IF;
        ELSIF COALESCE(open_count, 0) <> 1 THEN
          RAISE EXCEPTION 'current advisor must agree with open assignment history'
            USING ERRCODE = 'check_violation';
        ELSE
          SELECT advisor_membership_id
            INTO STRICT open_membership_id
            FROM client_advisor_assignments
            WHERE client_profile_id = target_profile_id
              AND effective_until IS NULL;

          IF open_membership_id IS DISTINCT FROM pointer THEN
            RAISE EXCEPTION 'current advisor must agree with open assignment history'
              USING ERRCODE = 'check_violation';
          END IF;
        END IF;

        RETURN NULL;
      END;
      $$;

      CREATE CONSTRAINT TRIGGER client_profiles_advisor_agrees_with_open_assignment
        AFTER INSERT OR UPDATE OR DELETE ON client_profiles
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW
        EXECUTE FUNCTION client_advisor_current_matches_open_assignment();

      CREATE CONSTRAINT TRIGGER client_advisor_assignments_agree_with_profile_pointer
        AFTER INSERT OR UPDATE OR DELETE ON client_advisor_assignments
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW
        EXECUTE FUNCTION client_advisor_current_matches_open_assignment();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS client_profiles_advisor_agrees_with_open_assignment ON client_profiles;
      DROP TRIGGER IF EXISTS client_advisor_assignments_agree_with_profile_pointer ON client_advisor_assignments;
      DROP FUNCTION IF EXISTS client_advisor_current_matches_open_assignment();
    SQL
  end
end
