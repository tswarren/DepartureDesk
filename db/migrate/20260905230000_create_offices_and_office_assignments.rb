class CreateOfficesAndOfficeAssignments < ActiveRecord::Migration[8.1]
  def up
    add_index :agency_memberships,
      [ :id, :agency_id ],
      unique: true,
      name: "index_agency_memberships_on_id_and_agency_id"

    create_table :offices,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :name, null: false
      table.string :code, null: false, limit: 10
      table.string :status, null: false, default: "active"
      table.string :default_timezone, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :offices,
      [ :agency_id, :code ],
      unique: true,
      name: "index_offices_on_agency_id_and_code"
    add_index :offices,
      [ :id, :agency_id ],
      unique: true,
      name: "index_offices_on_id_and_agency_id"

    add_check_constraint :offices, "btrim(name) <> ''", name: "offices_name_not_blank"
    add_check_constraint :offices, "code ~ '^[A-Z][A-Z0-9]{1,9}$'", name: "offices_code_format"
    add_check_constraint :offices, "status IN ('active', 'inactive')", name: "offices_status_valid"
    add_check_constraint :offices, "btrim(default_timezone) <> ''", name: "offices_timezone_not_blank"
    add_check_constraint :offices, "lock_version >= 0", name: "offices_lock_version_nonnegative"

    create_table :office_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :agency_membership, null: false, type: :uuid
      table.references :office, null: false, type: :uuid
      table.string :status, null: false, default: "active"
      table.boolean :is_default, null: false, default: false
      table.timestamptz :granted_at, null: false
      table.timestamptz :revoked_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :office_assignments,
      [ :agency_membership_id, :office_id ],
      unique: true,
      name: "index_office_assignments_on_membership_and_office"
    add_index :office_assignments,
      :agency_membership_id,
      unique: true,
      where: "is_default = TRUE",
      name: "index_office_assignments_one_default_per_membership"

    add_check_constraint :office_assignments,
      "status IN ('active', 'revoked')",
      name: "office_assignments_status_valid"
    add_check_constraint :office_assignments,
      "(status = 'active' AND revoked_at IS NULL) OR (status = 'revoked' AND revoked_at IS NOT NULL)",
      name: "office_assignments_revoked_at_matches_status"
    add_check_constraint :office_assignments,
      "is_default = FALSE OR status = 'active'",
      name: "office_assignments_default_only_when_active"
    add_check_constraint :office_assignments,
      "lock_version >= 0",
      name: "office_assignments_lock_version_nonnegative"

    execute <<~SQL
      ALTER TABLE office_assignments
        ADD CONSTRAINT office_assignments_office_same_agency_fk
        FOREIGN KEY (office_id, agency_id) REFERENCES offices (id, agency_id);
      ALTER TABLE office_assignments
        ADD CONSTRAINT office_assignments_membership_same_agency_fk
        FOREIGN KEY (agency_membership_id, agency_id) REFERENCES agency_memberships (id, agency_id);
    SQL

    add_reference :sessions, :office, type: :uuid, foreign_key: true, null: true

    execute <<~SQL
      INSERT INTO offices (
        id, agency_id, name, code, status, default_timezone, lock_version, created_at, updated_at
      )
      SELECT uuidv7(),
             agencies.id,
             agencies.name,
             'MAIN',
             'active',
             agencies.default_timezone,
             0,
             CURRENT_TIMESTAMP,
             CURRENT_TIMESTAMP
      FROM agencies
      WHERE NOT EXISTS (
        SELECT 1 FROM offices WHERE offices.agency_id = agencies.id
      );

      INSERT INTO office_assignments (
        id, agency_id, agency_membership_id, office_id, status, is_default,
        granted_at, revoked_at, lock_version, created_at, updated_at
      )
      SELECT uuidv7(),
             memberships.agency_id,
             memberships.id,
             offices.id,
             'active',
             TRUE,
             CURRENT_TIMESTAMP,
             NULL,
             0,
             CURRENT_TIMESTAMP,
             CURRENT_TIMESTAMP
      FROM agency_memberships AS memberships
      INNER JOIN offices
        ON offices.agency_id = memberships.agency_id
       AND offices.code = 'MAIN'
      WHERE memberships.status <> 'revoked'
        AND NOT EXISTS (
          SELECT 1
          FROM office_assignments
          WHERE office_assignments.agency_membership_id = memberships.id
        );
    SQL
  end

  def down
    remove_reference :sessions, :office, foreign_key: true
    drop_table :office_assignments
    drop_table :offices
    remove_index :agency_memberships, name: "index_agency_memberships_on_id_and_agency_id"
  end
end
