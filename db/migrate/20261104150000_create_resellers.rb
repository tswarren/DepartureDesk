# frozen_string_literal: true

# Slice 1 step 1 (ADR 0017, schema only): reseller relationships and the
# reseller user type. Invitations, the reseller namespace and its scope come
# in step 9.
class CreateResellers < ActiveRecord::Migration[8.1]
  def up
    create_table :resellers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.string :name, null: false
      table.string :status, null: false, default: "active"
      table.boolean :direct_contact_allowed, null: false, default: true
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :agency_id
      table.index %i[id agency_id], unique: true, name: "index_resellers_on_id_and_agency_id"
      table.check_constraint "btrim(name) <> '' AND char_length(name) <= 160", name: "resellers_name"
      table.check_constraint "status IN ('active', 'booking_paused', 'suspended', 'ended')", name: "resellers_status_valid"
      table.check_constraint "lock_version >= 0", name: "resellers_lock_version_nonnegative"
    end
    add_foreign_key :resellers, :agencies, column: :agency_id, name: "fk_resellers_agency"

    add_column :agency_users, :reseller_id, :uuid
    add_index :agency_users, :reseller_id
    execute <<~SQL
      ALTER TABLE agency_users
        ADD CONSTRAINT fk_agency_users_reseller_same_agency
        FOREIGN KEY (reseller_id, agency_id)
        REFERENCES resellers (id, agency_id);
    SQL

    remove_check_constraint :agency_users, name: "agency_users_user_type_valid"
    add_check_constraint :agency_users,
      "user_type IN ('agency_admin', 'staff', 'reseller')",
      name: "agency_users_user_type_valid"
    add_check_constraint :agency_users,
      "(user_type = 'reseller') = (reseller_id IS NOT NULL)",
      name: "agency_users_reseller_iff_reseller_type"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
