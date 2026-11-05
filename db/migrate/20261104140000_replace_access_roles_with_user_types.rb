# frozen_string_literal: true

# Slice 1 step 1 (ADR 0017): access roles become user types, and staff hold
# per-user permission grants. administrator becomes agency_admin; staff and
# viewer become staff with no grants. The reseller type arrives with the
# reseller schema.
class ReplaceAccessRolesWithUserTypes < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :agency_users, name: "agency_users_access_role_valid"
    rename_column :agency_users, :access_role, :user_type
    execute <<~SQL
      UPDATE agency_users SET user_type = 'agency_admin' WHERE user_type = 'administrator';
      UPDATE agency_users SET user_type = 'staff' WHERE user_type = 'viewer';
    SQL
    add_check_constraint :agency_users,
      "user_type IN ('agency_admin', 'staff')",
      name: "agency_users_user_type_valid"
    add_index :agency_users, %i[agency_id id user_type],
      unique: true,
      name: "index_agency_users_on_agency_id_id_user_type"

    create_table :user_permissions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :agency_user_id, null: false
      table.string :permission, null: false
      table.string :user_type, null: false, default: "staff"
      table.timestamps

      table.index %i[agency_id agency_user_id permission],
        unique: true,
        name: "index_user_permissions_on_agency_user_permission"
      table.index :agency_user_id
      table.check_constraint <<~SQL.squish, name: "user_permissions_permission_valid"
        permission IN (
          'departure_management',
          'supplier_arrangements',
          'financial_records',
          'passport_access',
          'reseller_relationships'
        )
      SQL
      table.check_constraint "user_type = 'staff'", name: "user_permissions_staff_only"
    end
    add_foreign_key :user_permissions, :agencies, column: :agency_id, name: "fk_user_permissions_agency"
    execute <<~SQL
      ALTER TABLE user_permissions
        ADD CONSTRAINT fk_user_permissions_staff_user
        FOREIGN KEY (agency_id, agency_user_id, user_type)
        REFERENCES agency_users (agency_id, id, user_type)
        ON UPDATE CASCADE;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
