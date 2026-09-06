class AddTypedKindProfilesAndAlternateNameRemoval < ActiveRecord::Migration[8.1]
  def up
    add_index :parties,
      [ :id, :agency_id, :party_kind ],
      unique: true,
      name: "index_parties_on_id_agency_id_and_party_kind"

    type_kind_profile(:people, "person")
    type_kind_profile(:households, "household")
    type_kind_profile(:organizations, "organization")

    add_column :party_alternate_names, :removed_by_membership_id, :uuid
    add_column :party_alternate_names, :removed_at, :timestamptz
    add_index :party_alternate_names, :removed_by_membership_id

    add_check_constraint :party_alternate_names,
      <<~SQL.squish,
        (status = 'active'
          AND removed_at IS NULL
          AND removed_by_membership_id IS NULL)
        OR
        (status = 'removed'
          AND removed_at IS NOT NULL
          AND removed_by_membership_id IS NOT NULL)
      SQL
      name: "party_alternate_names_removal_matches_status"

    execute <<~SQL
      ALTER TABLE party_alternate_names
        ADD CONSTRAINT party_alternate_names_removed_by_membership_same_agency_fk
        FOREIGN KEY (removed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE party_alternate_names
        DROP CONSTRAINT party_alternate_names_removed_by_membership_same_agency_fk;
    SQL
    remove_check_constraint :party_alternate_names, name: "party_alternate_names_removal_matches_status"
    remove_index :party_alternate_names, :removed_by_membership_id
    remove_column :party_alternate_names, :removed_at
    remove_column :party_alternate_names, :removed_by_membership_id

    untype_kind_profile(:organizations, "organization")
    untype_kind_profile(:households, "household")
    untype_kind_profile(:people, "person")
    remove_index :parties, name: "index_parties_on_id_agency_id_and_party_kind"
  end

  private

  def type_kind_profile(table, kind)
    add_column table, :party_kind, :string, null: false, default: kind
    add_check_constraint table, "party_kind = #{quote(kind)}", name: "#{table}_party_kind_#{kind}"

    execute "ALTER TABLE #{table} DROP CONSTRAINT #{table}_party_same_agency_fk"
    execute <<~SQL
      ALTER TABLE #{table}
        ADD CONSTRAINT #{table}_party_kind_same_agency_fk
        FOREIGN KEY (party_id, agency_id, party_kind)
        REFERENCES parties (id, agency_id, party_kind);
    SQL
  end

  def untype_kind_profile(table, kind)
    execute "ALTER TABLE #{table} DROP CONSTRAINT #{table}_party_kind_same_agency_fk"
    execute <<~SQL
      ALTER TABLE #{table}
        ADD CONSTRAINT #{table}_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id)
        REFERENCES parties (id, agency_id);
    SQL
    remove_check_constraint table, name: "#{table}_party_kind_#{kind}"
    remove_column table, :party_kind
  end
end
