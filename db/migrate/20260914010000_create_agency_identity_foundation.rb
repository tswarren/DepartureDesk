class CreateAgencyIdentityFoundation < ActiveRecord::Migration[8.1]
  def up
    create_agencies
    create_offices
    create_agency_users
    create_sessions
    create_audit_events
    add_office_default_foreign_key
  end

  def down
    drop_table :audit_events
    drop_table :sessions
    drop_table :agency_users
    drop_table :offices
    drop_table :agencies
  end

  private

  def create_agencies
    create_table :agencies, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.string :name, null: false
      table.string :legal_name
      table.string :workspace_code, null: false
      table.string :country_code, null: false, limit: 2
      table.string :default_currency, null: false, limit: 3
      table.string :default_timezone, null: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :agencies, :workspace_code, unique: true, name: "index_agencies_on_workspace_code"
    add_check_constraint :agencies, "status IN ('active', 'suspended', 'closed')", name: "agencies_status_valid"
    add_check_constraint :agencies, "lock_version >= 0", name: "agencies_lock_version_nonnegative"
    add_check_constraint :agencies, "btrim(name) <> ''", name: "agencies_name_not_blank"
    add_check_constraint :agencies, "workspace_code ~ '^[a-z][a-z0-9-]{1,39}$'", name: "agencies_workspace_code_format"
    add_check_constraint :agencies, "country_code ~ '^[A-Z]{2}$'", name: "agencies_country_code_format"
    add_check_constraint :agencies, "default_currency ~ '^[A-Z]{3}$'", name: "agencies_currency_format"
  end

  def create_offices
    create_table :offices, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :name, null: false
      table.string :code, null: false
      table.string :default_timezone, null: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :offices, [ :id, :agency_id ], unique: true, name: "index_offices_on_id_and_agency_id"
    add_index :offices, [ :agency_id, :code ], unique: true, name: "index_offices_on_agency_id_and_code"
    add_check_constraint :offices, "status IN ('active', 'inactive')", name: "offices_status_valid"
    add_check_constraint :offices, "lock_version >= 0", name: "offices_lock_version_nonnegative"
    add_check_constraint :offices, "btrim(name) <> ''", name: "offices_name_not_blank"
    add_check_constraint :offices, "code ~ '^[A-Z][A-Z0-9]{1,9}$'", name: "offices_code_format"
  end

  def create_agency_users
    create_table :agency_users, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :default_office_id
      table.string :email_address, null: false
      table.string :password_digest
      table.string :first_name, null: false
      table.string :last_name, null: false
      table.string :preferred_name
      table.string :title
      table.string :phone
      table.string :relationship
      table.string :access_role, null: false
      table.string :status, null: false, default: "invited"
      table.string :invitation_token_digest
      table.timestamptz :invitation_sent_at
      table.timestamptz :invitation_expires_at
      table.string :password_reset_token_digest
      table.timestamptz :password_reset_sent_at
      table.timestamptz :password_reset_expires_at
      table.integer :credential_version, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :agency_users, [ :agency_id, :email_address ], unique: true, name: "index_agency_users_on_agency_id_and_email"
    add_index :agency_users, [ :id, :agency_id ], unique: true, name: "index_agency_users_on_id_and_agency_id"
    add_index :agency_users, :invitation_token_digest, unique: true, where: "invitation_token_digest IS NOT NULL", name: "index_agency_users_on_invitation_token_digest"
    add_index :agency_users, :password_reset_token_digest, unique: true, where: "password_reset_token_digest IS NOT NULL", name: "index_agency_users_on_password_reset_token_digest"
    add_check_constraint :agency_users, "access_role IN ('administrator', 'staff', 'viewer')", name: "agency_users_access_role_valid"
    add_check_constraint :agency_users, "status IN ('invited', 'active', 'suspended', 'closed')", name: "agency_users_status_valid"
    add_check_constraint :agency_users, "credential_version >= 0", name: "agency_users_credential_version_nonnegative"
    add_check_constraint :agency_users, "lock_version >= 0", name: "agency_users_lock_version_nonnegative"
    add_check_constraint :agency_users, "btrim(email_address) <> ''", name: "agency_users_email_not_blank"
    add_check_constraint :agency_users, "btrim(first_name) <> '' AND btrim(last_name) <> ''", name: "agency_users_name_not_blank"
    add_check_constraint :agency_users,
      <<~SQL.squish,
        (status = 'invited' AND invitation_token_digest IS NOT NULL AND invitation_expires_at IS NOT NULL AND password_digest IS NULL)
        OR (status = 'active' AND password_digest IS NOT NULL AND invitation_token_digest IS NULL)
        OR (status IN ('suspended', 'closed') AND invitation_token_digest IS NULL)
      SQL
      name: "agency_users_status_credentials"
  end

  def create_sessions
    create_table :sessions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency_user, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id
      table.integer :credential_version, null: false
      table.string :ip_address
      table.string :user_agent
      table.timestamps null: false
    end

    add_index :sessions, :office_id, name: "index_sessions_on_office_id"
    execute <<~SQL
      ALTER TABLE sessions
        ADD CONSTRAINT sessions_office_fk
        FOREIGN KEY (office_id)
        REFERENCES offices (id);
    SQL
  end

  def create_audit_events
    create_table :audit_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :action, null: false
      table.string :actor_kind, null: false
      table.uuid :actor_agency_user_id
      table.string :actor_identifier
      table.string :subject_type
      table.uuid :subject_id
      table.jsonb :details, null: false, default: {}
      table.timestamps null: false
    end

    add_index :audit_events, [ :agency_id, :created_at ], name: "index_audit_events_on_agency_id_and_created_at"
    add_check_constraint :audit_events, "actor_kind IN ('agency_user', 'system')", name: "audit_events_actor_kind_valid"
    add_check_constraint :audit_events,
      <<~SQL.squish,
        (actor_kind = 'agency_user' AND actor_agency_user_id IS NOT NULL AND actor_identifier IS NULL)
        OR (actor_kind = 'system' AND actor_identifier IS NOT NULL AND btrim(actor_identifier) <> '' AND actor_agency_user_id IS NULL)
      SQL
      name: "audit_events_actor_present"
    execute <<~SQL
      ALTER TABLE audit_events
        ADD CONSTRAINT audit_events_actor_agency_user_fk
        FOREIGN KEY (actor_agency_user_id, agency_id)
        REFERENCES agency_users (id, agency_id);

      CREATE FUNCTION reject_audit_event_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'audit events are append-only';
      END;
      $$;

      CREATE TRIGGER audit_events_reject_update
      BEFORE UPDATE OR DELETE ON audit_events
      FOR EACH ROW EXECUTE FUNCTION reject_audit_event_mutation();
    SQL
  end

  def add_office_default_foreign_key
    execute <<~SQL
      ALTER TABLE agency_users
        ADD CONSTRAINT agency_users_default_office_fk
        FOREIGN KEY (default_office_id, agency_id)
        REFERENCES offices (id, agency_id);
    SQL
  end
end
