# frozen_string_literal: true

class ConstrainCapacityBackedCostPoolOwner < ActiveRecord::Migration[8.1]
  def change
    add_index :capacity_pools,
      [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_capacity_pools_on_arrangement_owner"

    remove_foreign_key :supplier_cost_components, name: "supplier_cost_components_quantity_pool_fk"
    add_foreign_key :supplier_cost_components, :capacity_pools,
      column: [ :quantity_capacity_pool_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "supplier_cost_components_quantity_pool_fk"
  end
end
