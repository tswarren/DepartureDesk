# frozen_string_literal: true

# Slice 1 step 3a (SUP-02): a supplier's payee accounts. Payment instructions
# are free text; structured bank fields are deferred.
class CreatePayeeAccounts < ActiveRecord::Migration[8.1]
  def up
    create_table :payee_accounts, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_id, null: false
      table.string :name, null: false
      table.string :currency, null: false
      table.text :payment_instructions
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[supplier_id name], unique: true, name: "index_payee_accounts_on_supplier_and_name"
      table.index %i[id agency_id], unique: true, name: "index_payee_accounts_on_id_and_agency_id"
      table.index %i[id supplier_id], unique: true, name: "index_payee_accounts_on_id_and_supplier_id"
      table.check_constraint "btrim(name) <> '' AND char_length(name) <= 120", name: "payee_accounts_name"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "payee_accounts_currency"
      table.check_constraint "payment_instructions IS NULL OR char_length(payment_instructions) <= 4000", name: "payee_accounts_instructions"
      table.check_constraint "lock_version >= 0", name: "payee_accounts_lock_version"
    end
    add_foreign_key :payee_accounts, :agencies, column: :agency_id, name: "fk_payee_accounts_agency"
    execute <<~SQL
      ALTER TABLE payee_accounts
        ADD CONSTRAINT fk_payee_accounts_supplier_same_agency
        FOREIGN KEY (supplier_id, agency_id) REFERENCES suppliers (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
