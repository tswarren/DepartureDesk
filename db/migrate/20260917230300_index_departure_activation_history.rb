class IndexDepartureActivationHistory < ActiveRecord::Migration[8.1]
  def change
    add_index :supplier_arrangement_activations,
      [ :agency_id, :departure_id, :supplier_arrangement_id, :activated_at ],
      name: "index_arrangement_activations_on_departure_history"
  end
end
