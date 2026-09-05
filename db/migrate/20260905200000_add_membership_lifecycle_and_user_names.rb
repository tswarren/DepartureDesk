class AddMembershipLifecycleAndUserNames < ActiveRecord::Migration[8.1]
  BOOTSTRAP_EMAIL = "email@example.com"
  BOOTSTRAP_FIRST_NAME = "Alex"
  BOOTSTRAP_LAST_NAME = "Mariner"

  def up
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :preferred_name, :string

    execute <<~SQL
      UPDATE users
      SET first_name = #{quote(BOOTSTRAP_FIRST_NAME)},
          last_name = #{quote(BOOTSTRAP_LAST_NAME)}
      WHERE email_address = #{quote(BOOTSTRAP_EMAIL)}
        AND (
          first_name IS NULL
          OR btrim(first_name) = ''
          OR last_name IS NULL
          OR btrim(last_name) = ''
        )
    SQL

    incomplete = select_value(<<~SQL.squish)
      SELECT COUNT(*)
      FROM users
      WHERE first_name IS NULL
        OR btrim(first_name) = ''
        OR last_name IS NULL
        OR btrim(last_name) = ''
    SQL

    if incomplete.to_i.positive?
      raise "Assign first_name and last_name to remaining users before adding NOT NULL"
    end

    change_column_null :users, :first_name, false
    change_column_null :users, :last_name, false

    add_check_constraint :users,
      "btrim(first_name) <> ''",
      name: "users_first_name_not_blank"

    add_check_constraint :users,
      "btrim(last_name) <> ''",
      name: "users_last_name_not_blank"

    add_check_constraint :users,
      "preferred_name IS NULL OR btrim(preferred_name) <> ''",
      name: "users_preferred_name_null_or_not_blank"

    add_column :agency_memberships, :invitation_version, :integer, null: false, default: 0
    add_column :agency_memberships, :invitation_sent_at, :timestamptz

    add_check_constraint :agency_memberships,
      "invitation_version >= 0",
      name: "agency_memberships_invitation_version_nonnegative"

    remove_check_constraint :agency_memberships, name: "agency_memberships_status_valid"
    add_check_constraint :agency_memberships,
      "status IN ('invited', 'active', 'suspended', 'revoked')",
      name: "agency_memberships_status_valid"
  end

  def down
    remove_check_constraint :agency_memberships, name: "agency_memberships_status_valid"
    add_check_constraint :agency_memberships,
      "status IN ('active', 'suspended')",
      name: "agency_memberships_status_valid"

    remove_check_constraint :agency_memberships, name: "agency_memberships_invitation_version_nonnegative"
    remove_column :agency_memberships, :invitation_sent_at
    remove_column :agency_memberships, :invitation_version

    remove_check_constraint :users, name: "users_preferred_name_null_or_not_blank"
    remove_check_constraint :users, name: "users_last_name_not_blank"
    remove_check_constraint :users, name: "users_first_name_not_blank"
    remove_column :users, :preferred_name
    remove_column :users, :last_name
    remove_column :users, :first_name
  end
end
