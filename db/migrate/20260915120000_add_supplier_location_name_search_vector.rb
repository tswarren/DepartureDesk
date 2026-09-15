class AddSupplierLocationNameSearchVector < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE supplier_locations
        ADD COLUMN name_search_vector tsvector
          GENERATED ALWAYS AS (to_tsvector('simple', dd_search_normalize(name))) STORED;
    SQL

    add_index :supplier_locations, :name_search_vector,
      using: :gin,
      name: "index_supplier_locations_on_name_search_vector"
  end

  def down
    remove_index :supplier_locations, name: "index_supplier_locations_on_name_search_vector"
    remove_column :supplier_locations, :name_search_vector
  end
end
