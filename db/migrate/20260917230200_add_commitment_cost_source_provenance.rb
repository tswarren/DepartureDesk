class AddCommitmentCostSourceProvenance < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :supplier_commitments, :supplier_cost_sources,
      column: [
        :supplier_cost_source_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id,
        :departure_id, :agency_id
      ],
      name: "supplier_commitments_cost_source_fk"
  end
end
