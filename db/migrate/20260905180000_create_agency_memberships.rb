class CreateAgencyMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_memberships,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :user, null: false, type: :uuid, foreign_key: true
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :role, null: false
      table.string :status, null: false
      table.integer :lock_version,
        null: false,
        default: 0

      table.timestamps null: false
    end

    add_index :agency_memberships,
      [ :user_id, :agency_id ],
      unique: true,
      name: "index_agency_memberships_on_user_id_and_agency_id"

    add_index :agency_memberships,
      :user_id,
      unique: true,
      where: "status = 'active'",
      name: "index_agency_memberships_one_active_per_user"

    add_index :agency_memberships,
      [ :agency_id, :status ],
      name: "index_agency_memberships_on_agency_id_and_status"

    add_check_constraint :agency_memberships,
      "role IN ('staff', 'administrator')",
      name: "agency_memberships_role_valid"

    add_check_constraint :agency_memberships,
      "status IN ('active', 'suspended')",
      name: "agency_memberships_status_valid"

    add_check_constraint :agency_memberships,
      "lock_version >= 0",
      name: "agency_memberships_lock_version_nonnegative"
  end
end
