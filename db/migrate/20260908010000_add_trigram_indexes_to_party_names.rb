class AddTrigramIndexesToPartyNames < ActiveRecord::Migration[8.1]
  def change
    add_index :parties, :display_name,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_parties_on_display_name_trgm"
    add_index :parties, :sort_name,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_parties_on_sort_name_trgm"
    add_index :party_alternate_names, :normalized_name,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_party_alternate_names_on_normalized_name_trgm"
  end
end
