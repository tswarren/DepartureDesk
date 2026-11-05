# frozen_string_literal: true

# Slice 1 step 3a (INV-01 to INV-04, INV-12, INV-39, SUP-15): an
# arrangement's inventory groups, each with one representation and an
# availability promise, and per-group capacity rules by traveler type.
class CreateInventoryGroups < ActiveRecord::Migration[8.1]
  CATEGORIES = %w[hotel all_inclusive_resort cruise air rail transportation activity meal insurance].freeze

  def up
    create_table :inventory_groups, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.string :label, null: false
      table.string :service_category, null: false
      table.string :representation, null: false
      table.string :availability_promise, null: false
      table.integer :quantity
      table.integer :positions_per_unit
      table.date :starts_on
      table.time :starts_at_time
      table.date :ends_on
      table.time :ends_at_time
      table.string :time_zone
      table.integer :position, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[supplier_arrangement_id position], name: "index_inventory_groups_on_arrangement_and_position"
      table.index %i[id agency_id], unique: true, name: "index_inventory_groups_on_id_and_agency_id"
      table.check_constraint "btrim(label) <> '' AND char_length(label) <= 120", name: "inventory_groups_label"
      table.check_constraint "service_category IN (#{CATEGORIES.map { |c| quote(c) }.join(", ")})", name: "inventory_groups_service_category"
      table.check_constraint "representation IN ('unit_shells', 'capacity_pool', 'none')", name: "inventory_groups_representation"
      table.check_constraint <<~SQL.squish, name: "inventory_groups_availability_promise"
        availability_promise IN ('firm_block', 'releasable_block', 'courtesy_option', 'on_request', 'rate_only')
      SQL
      # INV-04: On request and Rate only, and no shared inventory, hold no number.
      table.check_constraint <<~SQL.squish, name: "inventory_groups_quantity_only_when_numeric"
        quantity IS NULL OR (quantity >= 1 AND representation <> 'none' AND availability_promise NOT IN ('on_request', 'rate_only'))
      SQL
      table.check_constraint "positions_per_unit IS NULL OR (positions_per_unit >= 1 AND representation = 'unit_shells')", name: "inventory_groups_positions"
      table.check_constraint "(starts_on IS NULL) = (ends_on IS NULL) AND (starts_on IS NULL OR starts_on <= ends_on)", name: "inventory_groups_dates"
      table.check_constraint "starts_at_time IS NULL OR starts_on IS NOT NULL", name: "inventory_groups_start_time_needs_date"
      table.check_constraint "ends_at_time IS NULL OR ends_on IS NOT NULL", name: "inventory_groups_end_time_needs_date"
      table.check_constraint "position >= 0 AND lock_version >= 0", name: "inventory_groups_counters"
    end
    add_foreign_key :inventory_groups, :agencies, column: :agency_id, name: "fk_inventory_groups_agency"
    execute <<~SQL
      ALTER TABLE inventory_groups
        ADD CONSTRAINT fk_inventory_groups_arrangement_same_agency
        FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id);
    SQL

    create_table :capacity_rules, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :inventory_group_id, null: false
      table.uuid :traveler_type_id, null: false
      table.boolean :uses_capacity, null: false, default: false
      table.timestamps

      table.index %i[inventory_group_id traveler_type_id], unique: true, name: "index_capacity_rules_on_group_and_traveler_type"
    end
    add_foreign_key :capacity_rules, :agencies, column: :agency_id, name: "fk_capacity_rules_agency"
    execute <<~SQL
      ALTER TABLE capacity_rules
        ADD CONSTRAINT fk_capacity_rules_group_same_agency
        FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id),
        ADD CONSTRAINT fk_capacity_rules_traveler_type_same_agency
        FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
