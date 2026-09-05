class CreateDeliveryIntents < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_reset_version, :integer, null: false, default: 0
    add_check_constraint :users,
      "password_reset_version >= 0",
      name: "users_password_reset_version_nonnegative"

    create_table :delivery_intents,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: true, type: :uuid, foreign_key: true
      table.string :subject_type, null: false
      table.uuid :subject_id, null: false
      table.string :purpose, null: false
      table.integer :subject_version, null: false
      table.string :idempotency_key, null: false
      table.string :status, null: false, default: "pending"
      table.integer :attempt_count, null: false, default: 0
      table.timestamptz :available_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      table.timestamptz :claimed_at
      table.timestamptz :delivered_at
      table.text :last_error
      table.timestamps null: false
    end

    add_index :delivery_intents, :idempotency_key, unique: true
    add_index :delivery_intents,
      [ :status, :available_at ],
      name: "index_delivery_intents_for_reconciliation"
    add_index :delivery_intents,
      [ :subject_type, :subject_id ],
      name: "index_delivery_intents_on_subject"
    add_check_constraint :delivery_intents,
      "status IN ('pending', 'processing', 'succeeded', 'discarded')",
      name: "delivery_intents_status_valid"
    add_check_constraint :delivery_intents,
      "attempt_count >= 0 AND subject_version >= 0",
      name: "delivery_intents_counts_nonnegative"
    add_check_constraint :delivery_intents,
      "purpose IN ('team_invitation', 'password_reset')",
      name: "delivery_intents_purpose_valid"
    add_check_constraint :delivery_intents,
      "(status = 'succeeded' AND delivered_at IS NOT NULL) OR (status <> 'succeeded' AND delivered_at IS NULL)",
      name: "delivery_intents_success_has_delivery_time"
  end
end
