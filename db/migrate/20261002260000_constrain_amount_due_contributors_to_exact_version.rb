# frozen_string_literal: true

class ConstrainAmountDueContributorsToExactVersion < ActiveRecord::Migration[8.1]
  def change
    add_index :supplier_amount_due_definitions,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_amount_due_definitions_on_version_owner"
    add_index :supplier_cost_components,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true,
      name: "index_supplier_cost_components_on_version_owner"

    remove_foreign_key :supplier_amount_due_contributors, name: "amount_due_contributors_definition_fk"
    add_foreign_key :supplier_amount_due_contributors, :supplier_amount_due_definitions,
      column: [ :supplier_amount_due_definition_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_definition_fk"

    remove_foreign_key :supplier_amount_due_contributors, name: "amount_due_contributors_component_fk"
    add_foreign_key :supplier_amount_due_contributors, :supplier_cost_components,
      column: [ :supplier_cost_component_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "amount_due_contributors_component_fk"
  end
end
