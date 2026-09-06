class CreatePartiesAndKindProfiles < ActiveRecord::Migration[8.1]
  def up
    create_table :parties,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :party_kind, null: false
      table.string :display_name, null: false
      table.string :sort_name, null: false
      table.string :status, null: false, default: "active"
      table.timestamptz :deactivated_at
      table.uuid :deactivated_by_membership_id
      table.string :deactivation_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :parties,
      [ :id, :agency_id ],
      unique: true,
      name: "index_parties_on_id_and_agency_id"
    add_index :parties,
      [ :agency_id, :party_kind, :status ],
      name: "index_parties_on_agency_id_and_party_kind_and_status"
    add_index :parties,
      [ :agency_id, :sort_name ],
      name: "index_parties_on_agency_id_and_sort_name"

    add_check_constraint :parties,
      "party_kind IN ('person', 'household', 'organization')",
      name: "parties_party_kind_valid"
    add_check_constraint :parties,
      "status IN ('active', 'deactivated')",
      name: "parties_status_valid"
    add_check_constraint :parties,
      "btrim(display_name) <> ''",
      name: "parties_display_name_not_blank"
    add_check_constraint :parties,
      "btrim(sort_name) <> ''",
      name: "parties_sort_name_not_blank"
    add_check_constraint :parties,
      <<~SQL.squish,
        (status = 'active'
          AND deactivated_at IS NULL
          AND deactivated_by_membership_id IS NULL
          AND deactivation_reason IS NULL)
        OR
        (status = 'deactivated'
          AND deactivated_at IS NOT NULL
          AND deactivated_by_membership_id IS NOT NULL
          AND btrim(deactivation_reason) <> '')
      SQL
      name: "parties_deactivation_matches_status"
    add_check_constraint :parties,
      "lock_version >= 0",
      name: "parties_lock_version_nonnegative"

    execute <<~SQL
      ALTER TABLE parties
        ADD CONSTRAINT parties_deactivated_by_membership_same_agency_fk
        FOREIGN KEY (deactivated_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL

    execute <<~SQL
      CREATE FUNCTION parties_prevent_kind_or_agency_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.party_kind IS DISTINCT FROM OLD.party_kind THEN
          RAISE EXCEPTION 'party kind cannot change';
        END IF;
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'party agency cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER parties_kind_and_agency_immutable
        BEFORE UPDATE ON parties
        FOR EACH ROW
        EXECUTE FUNCTION parties_prevent_kind_or_agency_change();
    SQL

    create_kind_profile_table(:people) do |table|
      table.string :given_name, null: false
      table.string :middle_name
      table.string :family_name, null: false
      table.string :prefix
      table.string :suffix
      table.string :preferred_name
      table.string :form_of_address
      table.string :pronouns
      table.date :date_of_birth
    end

    add_check_constraint :people, "btrim(given_name) <> ''", name: "people_given_name_not_blank"
    add_check_constraint :people, "btrim(family_name) <> ''", name: "people_family_name_not_blank"
    add_check_constraint :people,
      "middle_name IS NULL OR btrim(middle_name) <> ''",
      name: "people_middle_name_null_or_not_blank"
    add_check_constraint :people,
      "prefix IS NULL OR btrim(prefix) <> ''",
      name: "people_prefix_null_or_not_blank"
    add_check_constraint :people,
      "suffix IS NULL OR btrim(suffix) <> ''",
      name: "people_suffix_null_or_not_blank"
    add_check_constraint :people,
      "preferred_name IS NULL OR btrim(preferred_name) <> ''",
      name: "people_preferred_name_null_or_not_blank"
    add_check_constraint :people,
      "form_of_address IS NULL OR btrim(form_of_address) <> ''",
      name: "people_form_of_address_null_or_not_blank"
    add_check_constraint :people,
      "pronouns IS NULL OR btrim(pronouns) <> ''",
      name: "people_pronouns_null_or_not_blank"
    add_check_constraint :people,
      "date_of_birth IS NULL OR date_of_birth <= CURRENT_DATE",
      name: "people_date_of_birth_not_future"

    create_kind_profile_table(:households) do |table|
      table.string :name, null: false
      table.string :correspondence_name
    end

    add_check_constraint :households, "btrim(name) <> ''", name: "households_name_not_blank"
    add_check_constraint :households,
      "correspondence_name IS NULL OR btrim(correspondence_name) <> ''",
      name: "households_correspondence_name_null_or_not_blank"

    create_kind_profile_table(:organizations) do |table|
      table.string :legal_name, null: false
      table.string :trading_name
      table.string :website
    end

    add_check_constraint :organizations, "btrim(legal_name) <> ''", name: "organizations_legal_name_not_blank"
    add_check_constraint :organizations,
      "trading_name IS NULL OR btrim(trading_name) <> ''",
      name: "organizations_trading_name_null_or_not_blank"
    add_check_constraint :organizations,
      "website IS NULL OR btrim(website) <> ''",
      name: "organizations_website_null_or_not_blank"

    create_table :party_alternate_names,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.uuid :party_id, null: false
      table.uuid :agency_id, null: false
      table.string :name_kind, null: false
      table.string :name, null: false
      table.string :normalized_name, null: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_alternate_names,
      [ :party_id, :name_kind, :normalized_name ],
      unique: true,
      where: "status = 'active'",
      name: "index_party_alternate_names_unique_active"
    add_index :party_alternate_names,
      [ :agency_id, :normalized_name ],
      name: "index_party_alternate_names_on_agency_id_and_normalized_name"

    add_check_constraint :party_alternate_names,
      "name_kind IN ('former_name', 'alias', 'additional_trading_name', 'acronym', 'imported_name')",
      name: "party_alternate_names_name_kind_valid"
    add_check_constraint :party_alternate_names,
      "status IN ('active', 'removed')",
      name: "party_alternate_names_status_valid"
    add_check_constraint :party_alternate_names,
      "btrim(name) <> ''",
      name: "party_alternate_names_name_not_blank"
    add_check_constraint :party_alternate_names,
      "btrim(normalized_name) <> ''",
      name: "party_alternate_names_normalized_name_not_blank"
    add_check_constraint :party_alternate_names,
      "lock_version >= 0",
      name: "party_alternate_names_lock_version_nonnegative"

    execute <<~SQL
      ALTER TABLE party_alternate_names
        ADD CONSTRAINT party_alternate_names_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id) REFERENCES parties (id, agency_id);
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS parties_kind_and_agency_immutable ON parties;
      DROP FUNCTION IF EXISTS parties_prevent_kind_or_agency_change();
    SQL
    drop_table :party_alternate_names
    drop_table :organizations
    drop_table :households
    drop_table :people
    drop_table :parties
  end

  private

  def create_kind_profile_table(name)
    create_table name, id: false, primary_key: :party_id do |table|
      table.uuid :party_id, null: false, primary_key: true
      table.uuid :agency_id, null: false
      yield table
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_foreign_key name, :agencies
    add_index name,
      [ :party_id, :agency_id ],
      unique: true,
      name: "index_#{name}_on_party_id_and_agency_id"
    add_check_constraint name, "lock_version >= 0", name: "#{name}_lock_version_nonnegative"

    execute <<~SQL
      ALTER TABLE #{name}
        ADD CONSTRAINT #{name}_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id) REFERENCES parties (id, agency_id);
    SQL
  end
end
