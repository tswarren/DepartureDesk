class CreateAgencies < ActiveRecord::Migration[8.1]
  def change
    create_table :agencies,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.string :name, null: false
      table.string :default_timezone, null: false, default: "UTC"
      table.string :default_currency,
        null: false,
        limit: 3,
        default: "USD"
      table.string :status,
        null: false,
        default: "active"
      table.integer :lock_version,
        null: false,
        default: 0

      table.timestamps null: false
    end

    add_check_constraint :agencies,
      "btrim(name) <> ''",
      name: "agencies_name_not_blank"

    add_check_constraint :agencies,
      "btrim(default_timezone) <> ''",
      name: "agencies_timezone_not_blank"

    add_check_constraint :agencies,
      "default_currency ~ '^[A-Z]{3}$'",
      name: "agencies_currency_format"

    add_check_constraint :agencies,
      "status IN ('active', 'suspended', 'closed')",
      name: "agencies_status_valid"

    add_check_constraint :agencies,
      "lock_version >= 0",
      name: "agencies_lock_version_nonnegative"
  end
end
