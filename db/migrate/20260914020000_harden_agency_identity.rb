class HardenAgencyIdentity < ActiveRecord::Migration[8.1]
  def up
    add_check_constraint :agency_users,
      "email_address = lower(btrim(email_address))",
      name: "agency_users_email_normalized"

    execute <<~SQL
      CREATE FUNCTION reject_agency_workspace_code_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.workspace_code IS DISTINCT FROM OLD.workspace_code THEN
          RAISE EXCEPTION 'workspace_code is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE FUNCTION reject_agency_user_agency_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'agency_id is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE FUNCTION reject_office_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.code IS DISTINCT FROM OLD.code THEN
          RAISE EXCEPTION 'office identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER agencies_reject_workspace_code_change
      BEFORE UPDATE ON agencies
      FOR EACH ROW EXECUTE FUNCTION reject_agency_workspace_code_change();

      CREATE TRIGGER agency_users_reject_agency_id_change
      BEFORE UPDATE ON agency_users
      FOR EACH ROW EXECUTE FUNCTION reject_agency_user_agency_change();

      CREATE TRIGGER offices_reject_identity_change
      BEFORE UPDATE ON offices
      FOR EACH ROW EXECUTE FUNCTION reject_office_identity_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER agencies_reject_workspace_code_change ON agencies;
      DROP TRIGGER agency_users_reject_agency_id_change ON agency_users;
      DROP TRIGGER offices_reject_identity_change ON offices;
      DROP FUNCTION reject_agency_workspace_code_change();
      DROP FUNCTION reject_agency_user_agency_change();
      DROP FUNCTION reject_office_identity_change();
    SQL
    remove_check_constraint :agency_users, name: "agency_users_email_normalized"
  end
end
