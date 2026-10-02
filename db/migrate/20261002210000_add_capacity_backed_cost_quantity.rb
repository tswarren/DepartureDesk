# frozen_string_literal: true

class AddCapacityBackedCostQuantity < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_cost_components, :quantity_capacity_pool_id, :uuid
    add_index :supplier_cost_components, :quantity_capacity_pool_id,
      name: "index_supplier_cost_components_on_quantity_pool"
    add_foreign_key :supplier_cost_components, :capacity_pools,
      column: [ :quantity_capacity_pool_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_cost_components_quantity_pool_fk"
    add_check_constraint :supplier_cost_components,
      <<~SQL.squish,
        quantity_capacity_pool_id IS NULL OR (
          calculation_kind = 'unit_rate' AND quantity_basis = 'resource_units'
        )
      SQL
      name: "supplier_cost_components_quantity_pool_shape"
  end
end
