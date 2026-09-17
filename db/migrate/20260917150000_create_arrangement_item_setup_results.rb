class CreateArrangementItemSetupResults < ActiveRecord::Migration[8.1]
  def up
    create_table :arrangement_item_setup_results,
      id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.references :agency_command_idempotency_key, null: false, type: :uuid,
        index: { unique: true, name: "index_item_setup_results_on_idempotency_key" }
      table.references :arrangement_item, null: false, type: :uuid
      table.references :service_occurrence, null: true, type: :uuid
      table.references :supplier_resource, null: true, type: :uuid
      table.timestamps
    end

    add_foreign_key :arrangement_item_setup_results, :agency_command_idempotency_keys,
      column: %i[agency_command_idempotency_key_id agency_id],
      primary_key: %i[id agency_id],
      name: "item_setup_results_idempotency_key_fk"
    add_foreign_key :arrangement_item_setup_results, :arrangement_items,
      column: %i[arrangement_item_id agency_id],
      primary_key: %i[id agency_id],
      name: "item_setup_results_item_fk",
      on_delete: :cascade
  end

  def down
    drop_table :arrangement_item_setup_results
  end
end
