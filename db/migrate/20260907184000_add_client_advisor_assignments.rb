class AddClientAdvisorAssignments < ActiveRecord::Migration[8.1]
  RESTRICTION_LIMIT = 2000

  def up
    add_column :client_profiles, :primary_advisor_membership_id, :uuid
    add_column :client_profiles, :primary_advisor_membership_status, :string
    add_column :client_profiles, :communication_preference, :string, null: false, default: "no_preference"
    add_column :client_profiles, :servicing_restrictions, :text
    add_column :client_profiles, :billing_restrictions, :text

    add_check_constraint :client_profiles,
      "communication_preference IN ('no_preference', 'email', 'phone', 'postal_mail')",
      name: "client_profiles_communication_preference_valid"
    add_check_constraint :client_profiles,
      "char_length(servicing_restrictions) <= #{RESTRICTION_LIMIT}",
      name: "client_profiles_servicing_restrictions_length"
    add_check_constraint :client_profiles,
      "char_length(billing_restrictions) <= #{RESTRICTION_LIMIT}",
      name: "client_profiles_billing_restrictions_length"
    add_check_constraint :client_profiles,
      <<~SQL.squish,
        (primary_advisor_membership_id IS NULL AND primary_advisor_membership_status IS NULL)
        OR (primary_advisor_membership_id IS NOT NULL AND primary_advisor_membership_status = 'active')
      SQL
      name: "client_profiles_advisor_projection"

    remove_check_constraint :client_profiles, name: "client_profiles_lifecycle_and_status_projections"
    add_check_constraint :client_profiles,
      <<~SQL.squish,
        (status = 'active'
          AND party_status IS NOT NULL
          AND party_status = 'active'
          AND responsible_office_status IS NOT NULL
          AND responsible_office_status = 'active'
          AND deactivated_at IS NULL
          AND deactivated_by_membership_id IS NULL
          AND deactivation_reason IS NULL)
        OR
        (status = 'inactive'
          AND party_status IS NULL
          AND responsible_office_status IS NULL
          AND primary_advisor_membership_id IS NULL
          AND primary_advisor_membership_status IS NULL
          AND deactivated_at IS NOT NULL
          AND deactivated_by_membership_id IS NOT NULL
          AND btrim(deactivation_reason) <> '')
      SQL
      name: "client_profiles_lifecycle_and_status_projections"

    execute <<~SQL
      ALTER TABLE client_profiles
        ADD CONSTRAINT client_profiles_advisor_same_agency_fk
        FOREIGN KEY (primary_advisor_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE client_profiles
        ADD CONSTRAINT client_profiles_advisor_active_projection_fk
        FOREIGN KEY (primary_advisor_membership_id, agency_id, primary_advisor_membership_status)
        REFERENCES agency_memberships (id, agency_id, status);
    SQL

    create_table :client_advisor_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :client_profile_id, null: false
      table.uuid :advisor_membership_id, null: false
      table.date :effective_from, null: false
      table.date :effective_until
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :client_advisor_assignments,
      [ :id, :agency_id ],
      unique: true,
      name: "index_client_advisor_assignments_on_id_and_agency_id"
    add_index :client_advisor_assignments,
      [ :client_profile_id, :agency_id ],
      name: "index_client_advisor_assignments_on_profile"
    add_index :client_advisor_assignments,
      [ :advisor_membership_id, :agency_id ],
      name: "index_client_advisor_assignments_on_membership"

    add_check_constraint :client_advisor_assignments,
      "effective_until IS NULL OR effective_until >= effective_from",
      name: "caa_range_order"
    add_check_constraint :client_advisor_assignments,
      "lock_version >= 0",
      name: "caa_lock_version_nonnegative"
    add_check_constraint :client_advisor_assignments,
      <<~SQL.squish,
        (ended_at IS NULL AND ended_by_membership_id IS NULL AND ending_reason IS NULL AND effective_until IS NULL)
        OR (ended_at IS NOT NULL AND ended_by_membership_id IS NOT NULL AND btrim(ending_reason) <> '' AND effective_until IS NOT NULL)
      SQL
      name: "caa_ending_complete"

    execute <<~SQL
      ALTER TABLE client_advisor_assignments
        ADD CONSTRAINT caa_profile_same_agency_fk
        FOREIGN KEY (client_profile_id, agency_id)
        REFERENCES client_profiles (id, agency_id);
      ALTER TABLE client_advisor_assignments
        ADD CONSTRAINT caa_advisor_same_agency_fk
        FOREIGN KEY (advisor_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE client_advisor_assignments
        ADD CONSTRAINT caa_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE client_advisor_assignments
        ADD CONSTRAINT caa_no_overlapping_intervals
        EXCLUDE USING gist (
          agency_id WITH =,
          client_profile_id WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        );
    SQL

    execute <<~SQL
      CREATE FUNCTION client_advisor_assignments_prevent_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
          OR NEW.advisor_membership_id IS DISTINCT FROM OLD.advisor_membership_id
          OR NEW.effective_from IS DISTINCT FROM OLD.effective_from THEN
          RAISE EXCEPTION 'advisor assignment identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER client_advisor_assignments_identity_immutable
        BEFORE UPDATE ON client_advisor_assignments
        FOR EACH ROW
        EXECUTE FUNCTION client_advisor_assignments_prevent_identity_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS client_advisor_assignments_identity_immutable ON client_advisor_assignments;
      DROP FUNCTION IF EXISTS client_advisor_assignments_prevent_identity_change();
    SQL
    drop_table :client_advisor_assignments
    execute <<~SQL
      ALTER TABLE client_profiles DROP CONSTRAINT IF EXISTS client_profiles_advisor_active_projection_fk;
      ALTER TABLE client_profiles DROP CONSTRAINT IF EXISTS client_profiles_advisor_same_agency_fk;
    SQL
    remove_check_constraint :client_profiles, name: "client_profiles_lifecycle_and_status_projections"
    add_check_constraint :client_profiles,
      <<~SQL.squish,
        (status = 'active'
          AND party_status IS NOT NULL
          AND party_status = 'active'
          AND responsible_office_status IS NOT NULL
          AND responsible_office_status = 'active'
          AND deactivated_at IS NULL
          AND deactivated_by_membership_id IS NULL
          AND deactivation_reason IS NULL)
        OR
        (status = 'inactive'
          AND party_status IS NULL
          AND responsible_office_status IS NULL
          AND deactivated_at IS NOT NULL
          AND deactivated_by_membership_id IS NOT NULL
          AND btrim(deactivation_reason) <> '')
      SQL
      name: "client_profiles_lifecycle_and_status_projections"
    remove_check_constraint :client_profiles, name: "client_profiles_advisor_projection"
    remove_check_constraint :client_profiles, name: "client_profiles_billing_restrictions_length"
    remove_check_constraint :client_profiles, name: "client_profiles_servicing_restrictions_length"
    remove_check_constraint :client_profiles, name: "client_profiles_communication_preference_valid"
    remove_column :client_profiles, :billing_restrictions
    remove_column :client_profiles, :servicing_restrictions
    remove_column :client_profiles, :communication_preference
    remove_column :client_profiles, :primary_advisor_membership_status
    remove_column :client_profiles, :primary_advisor_membership_id
  end
end
