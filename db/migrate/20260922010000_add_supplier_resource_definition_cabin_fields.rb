# frozen_string_literal: true

class AddSupplierResourceDefinitionCabinFields < ActiveRecord::Migration[8.1]
  def change
    change_table :supplier_resource_definitions, bulk: true do |table|
      table.string :supplier_code, limit: 80
      table.integer :maximum_occupancy
    end

    add_check_constraint :supplier_resource_definitions,
      "supplier_code IS NULL OR (btrim(supplier_code) <> '' AND char_length(supplier_code) <= 80)",
      name: "supplier_resource_definitions_supplier_code"

    add_check_constraint :supplier_resource_definitions,
      "maximum_occupancy IS NULL OR maximum_occupancy > 0",
      name: "supplier_resource_definitions_maximum_occupancy"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          CREATE UNIQUE INDEX supplier_resource_defs_supplier_code_unique
          ON public.supplier_resource_definitions (
            supplier_arrangement_version_id,
            arrangement_item_id,
            lower(btrim(supplier_code))
          )
          WHERE supplier_code IS NOT NULL
        SQL
      end
      direction.down do
        execute "DROP INDEX IF EXISTS public.supplier_resource_defs_supplier_code_unique"
      end
    end
  end
end
