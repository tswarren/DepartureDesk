# frozen_string_literal: true

class AddTransportationCapacityCeiling < ActiveRecord::Migration[8.1]
  def change
    add_column :capacity_pool_definitions, :maximum_total_resource_units, :integer
    add_check_constraint :capacity_pool_definitions,
      <<~SQL.squish,
        maximum_total_resource_units IS NULL OR (
          maximum_total_resource_units > 0 AND (
            proposed_opening_quantity IS NULL OR
            maximum_total_resource_units >= proposed_opening_quantity
          )
        )
      SQL
      name: "capacity_pool_defs_maximum_total"
  end
end
