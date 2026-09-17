class AddM3d2ActivationContract < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_arrangement_activations,
      :cost_source_coverage_acknowledged, :boolean, null: false, default: false
    add_column :supplier_arrangement_activations,
      :commitment_trigger_coverage_acknowledged, :boolean, null: false, default: false

    add_index :supplier_arrangement_activations,
      [ :agency_id, :departure_id ],
      name: "index_arrangement_activations_on_departure_latch"
  end
end
