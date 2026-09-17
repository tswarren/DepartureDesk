class HardenArrangementItemSetupResultOwnership < ActiveRecord::Migration[8.1]
  def change
    add_index :service_occurrences,
      %i[id arrangement_item_id agency_id],
      unique: true,
      name: "index_service_occurrences_on_item_owner"
    add_index :supplier_resources,
      %i[id arrangement_item_id agency_id],
      unique: true,
      name: "index_supplier_resources_on_item_owner"

    add_foreign_key :arrangement_item_setup_results, :service_occurrences,
      column: %i[service_occurrence_id arrangement_item_id agency_id],
      primary_key: %i[id arrangement_item_id agency_id],
      name: "item_setup_results_occurrence_owner_fk"
    add_foreign_key :arrangement_item_setup_results, :supplier_resources,
      column: %i[supplier_resource_id arrangement_item_id agency_id],
      primary_key: %i[id arrangement_item_id agency_id],
      name: "item_setup_results_resource_owner_fk"
  end
end
