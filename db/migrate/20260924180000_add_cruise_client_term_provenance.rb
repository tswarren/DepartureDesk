# frozen_string_literal: true

class AddCruiseClientTermProvenance < ActiveRecord::Migration[8.1]
  def change
    change_table :service_offer_price_components, bulk: true do |table|
      table.string :cruise_client_term_row_key, limit: 80
      table.uuid :copied_from_supplier_cost_component_id
      table.string :copied_from_supplier_cost_component_fingerprint, limit: 64
      table.timestamptz :copied_from_supplier_cost_component_at
      table.jsonb :copied_from_supplier_cost_component_mapping
    end

    add_check_constraint :service_offer_price_components,
      "cruise_client_term_row_key IS NULL OR (btrim(cruise_client_term_row_key) <> '' AND char_length(cruise_client_term_row_key) <= 80)",
      name: "service_offer_price_components_row_key"
    add_check_constraint :service_offer_price_components,
      "(copied_from_supplier_cost_component_id IS NULL AND copied_from_supplier_cost_component_fingerprint IS NULL AND copied_from_supplier_cost_component_at IS NULL AND copied_from_supplier_cost_component_mapping IS NULL) OR " \
        "(copied_from_supplier_cost_component_id IS NOT NULL AND copied_from_supplier_cost_component_fingerprint IS NOT NULL AND copied_from_supplier_cost_component_at IS NOT NULL AND copied_from_supplier_cost_component_mapping IS NOT NULL)",
      name: "service_offer_price_components_provenance_complete"
    add_check_constraint :service_offer_price_components,
      "copied_from_supplier_cost_component_fingerprint IS NULL OR copied_from_supplier_cost_component_fingerprint ~ '^[0-9a-f]{64}$'",
      name: "service_offer_price_components_provenance_fingerprint"
    add_check_constraint :service_offer_price_components,
      "copied_from_supplier_cost_component_mapping IS NULL OR jsonb_typeof(copied_from_supplier_cost_component_mapping) = 'object'",
      name: "service_offer_price_components_provenance_mapping_object"

    add_index :service_offer_price_components,
      [ :service_offer_price_definition_id, :client_rate_category_key, :occupancy_position_key, :cruise_client_term_row_key ],
      unique: true,
      where: "cruise_client_term_row_key IS NOT NULL",
      name: "index_so_price_components_on_typed_cell"

    add_foreign_key :service_offer_price_components, :supplier_cost_components,
      column: [ :copied_from_supplier_cost_component_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "fk_so_price_components_supplier_cost_copy"
    add_index :service_offer_price_components, :copied_from_supplier_cost_component_id,
      where: "copied_from_supplier_cost_component_id IS NOT NULL",
      name: "index_so_price_components_on_supplier_copy"
  end
end
