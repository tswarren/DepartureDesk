class CreateClientAndSupplierProfiles < ActiveRecord::Migration[8.1]
  def up
    add_index :offices,
      [ :id, :agency_id, :status ],
      unique: true,
      name: "index_offices_on_id_agency_id_and_status"
    add_index :agency_memberships,
      [ :id, :agency_id, :status ],
      unique: true,
      name: "index_agency_memberships_on_id_agency_id_and_status"

    create_role_profile_table(:client_profiles, kinds: %w[person household organization], extra: :client)
    create_role_profile_table(:supplier_profiles, kinds: %w[person organization], extra: :supplier)

    execute <<~SQL
      CREATE FUNCTION role_profiles_prevent_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.party_id IS DISTINCT FROM OLD.party_id
          OR NEW.party_kind IS DISTINCT FROM OLD.party_kind THEN
          RAISE EXCEPTION 'agency_id, party_id, and party_kind are immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    %w[client_profiles supplier_profiles].each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_identity_immutable
          BEFORE UPDATE ON #{table}
          FOR EACH ROW
          EXECUTE FUNCTION role_profiles_prevent_identity_change();
      SQL
    end
  end

  def down
    %w[client_profiles supplier_profiles].each do |table|
      execute "DROP TRIGGER IF EXISTS #{table}_identity_immutable ON #{table};"
    end
    execute "DROP FUNCTION IF EXISTS role_profiles_prevent_identity_change();"
    drop_table :supplier_profiles
    drop_table :client_profiles
    remove_index :agency_memberships, name: "index_agency_memberships_on_id_agency_id_and_status"
    remove_index :offices, name: "index_offices_on_id_agency_id_and_status"
  end

  private

  def create_role_profile_table(table_name, kinds:, extra:)
    create_table table_name,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :party_id, null: false
      table.string :party_kind, null: false
      table.string :status, null: false, default: "active"
      table.uuid :responsible_office_id, null: false
      table.string :responsible_office_status
      table.timestamptz :deactivated_at
      table.uuid :deactivated_by_membership_id
      table.string :deactivation_reason
      table.integer :lock_version, null: false, default: 0
      if extra == :supplier
        table.string :default_currency, null: false, limit: 3
      end
      table.timestamps null: false
    end

    add_index table_name, [ :id, :agency_id ], unique: true, name: "index_#{table_name}_on_id_and_agency_id"
    add_index table_name, [ :party_id, :agency_id ], unique: true, name: "index_#{table_name}_on_party_id_and_agency_id"
    add_index table_name,
      [ :responsible_office_id, :agency_id ],
      name: "index_#{table_name}_on_office_id_and_agency_id"

    quoted_kinds = kinds.map { |kind| ActiveRecord::Base.connection.quote(kind) }.join(", ")
    add_check_constraint table_name,
      "party_kind IN (#{quoted_kinds})",
      name: "#{table_name}_party_kind_valid"
    add_check_constraint table_name,
      "status IN ('active', 'inactive')",
      name: "#{table_name}_status_valid"
    add_check_constraint table_name,
      <<~SQL.squish,
        (status = 'active'
          AND responsible_office_status IS NOT NULL
          AND responsible_office_status = 'active'
          AND deactivated_at IS NULL
          AND deactivated_by_membership_id IS NULL
          AND deactivation_reason IS NULL)
        OR
        (status = 'inactive'
          AND responsible_office_status IS NULL
          AND deactivated_at IS NOT NULL
          AND deactivated_by_membership_id IS NOT NULL
          AND btrim(deactivation_reason) <> '')
      SQL
      name: "#{table_name}_lifecycle_and_office_projection"
    add_check_constraint table_name,
      "lock_version >= 0",
      name: "#{table_name}_lock_version_nonnegative"
    if extra == :supplier
      add_check_constraint table_name,
        "default_currency ~ '^[A-Z]{3}$'",
        name: "supplier_profiles_currency_format"
    end

    execute <<~SQL
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{table_name}_party_kind_same_agency_fk
        FOREIGN KEY (party_id, agency_id, party_kind)
        REFERENCES parties (id, agency_id, party_kind);
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{table_name}_office_same_agency_fk
        FOREIGN KEY (responsible_office_id, agency_id)
        REFERENCES offices (id, agency_id);
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{table_name}_office_active_projection_fk
        FOREIGN KEY (responsible_office_id, agency_id, responsible_office_status)
        REFERENCES offices (id, agency_id, status);
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{table_name}_deactivated_by_membership_fk
        FOREIGN KEY (deactivated_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end
end
