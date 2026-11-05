# frozen_string_literal: true

# Slice 1 step 3a (SUP-06, SUP-07, SUP-10, SUP-11, SUP-15, SUP-16, SUP-18,
# ADR 0018): one arrangement record per supplier per Departure, with no
# versions. Draft is edited in place; Confirm and Discard are commands.
class CreateSupplierArrangements < ActiveRecord::Migration[8.1]
  def up
    create_table :supplier_arrangements, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_id, null: false
      table.uuid :payee_account_id
      table.string :arrangement_reference, null: false
      table.string :status, null: false, default: "draft"
      table.string :currency, null: false
      table.string :group_reference
      table.string :reservation_scope, null: false, default: "arrangement"
      table.string :obligation_shape
      table.string :default_availability_promise, null: false, default: "firm_block"
      table.text :covered_services
      table.text :terms
      table.date :confirmed_on
      table.text :confirmation_note
      table.datetime :confirmed_at
      table.datetime :cancelled_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[agency_id arrangement_reference], unique: true, name: "index_supplier_arrangements_on_agency_and_reference"
      table.index %i[departure_id supplier_id], unique: true, where: "status <> 'cancelled'",
        name: "index_supplier_arrangements_one_live_per_departure_supplier"
      table.index %i[id agency_id], unique: true, name: "index_supplier_arrangements_on_id_and_agency_id"
      table.index %i[id departure_id], unique: true, name: "index_supplier_arrangements_on_id_and_departure_id"
      table.check_constraint "status IN ('draft', 'confirmed', 'closed', 'cancelled')", name: "supplier_arrangements_status"
      table.check_constraint "arrangement_reference ~ '^ARR-[0-9]{4,}$'", name: "supplier_arrangements_reference_format"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "supplier_arrangements_currency"
      table.check_constraint "reservation_scope IN ('arrangement', 'per_unit', 'none')", name: "supplier_arrangements_reservation_scope"
      table.check_constraint <<~SQL.squish, name: "supplier_arrangements_obligation_shape"
        obligation_shape IS NULL OR obligation_shape IN ('per_unit_used', 'committed_quantity', 'fixed_resource_charge', 'minimum_pickup', 'mixed')
      SQL
      table.check_constraint <<~SQL.squish, name: "supplier_arrangements_default_promise"
        default_availability_promise IN ('firm_block', 'releasable_block', 'courtesy_option', 'on_request', 'rate_only')
      SQL
      table.check_constraint "group_reference IS NULL OR (btrim(group_reference) <> '' AND char_length(group_reference) <= 80)", name: "supplier_arrangements_group_reference"
      table.check_constraint <<~SQL.squish, name: "supplier_arrangements_confirmed_complete"
        status IN ('draft', 'cancelled')
        OR (group_reference IS NOT NULL AND payee_account_id IS NOT NULL AND confirmed_on IS NOT NULL AND confirmed_at IS NOT NULL)
      SQL
      table.check_constraint "(status = 'cancelled') = (cancelled_at IS NOT NULL)", name: "supplier_arrangements_cancelled_at_pair"
      table.check_constraint "lock_version >= 0", name: "supplier_arrangements_lock_version"
    end
    add_foreign_key :supplier_arrangements, :agencies, column: :agency_id, name: "fk_supplier_arrangements_agency"
    execute <<~SQL
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT fk_supplier_arrangements_departure_same_agency
        FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_supplier_arrangements_supplier_same_agency
        FOREIGN KEY (supplier_id, agency_id) REFERENCES suppliers (id, agency_id),
        ADD CONSTRAINT fk_supplier_arrangements_payee_of_supplier
        FOREIGN KEY (payee_account_id, supplier_id) REFERENCES payee_accounts (id, supplier_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
