class CreateClientOrganizationDirectory < ActiveRecord::Migration[8.1]
  def up
    create_client_organizations
    create_organization_contact_points
    widen_clients
    enable_extension "btree_gist"
    create_organization_contacts
  end

  def down
    drop_table :client_organization_contacts
    execute "DROP FUNCTION IF EXISTS reject_client_organization_contact_identity_change()"
    disable_extension "btree_gist"

    remove_check_constraint :clients, name: "clients_exactly_one_source"
    remove_foreign_key :clients, name: "clients_organization_agency_fk"
    remove_index :clients, name: "index_clients_on_client_organization_id"
    change_column_null :clients, :client_organization_id, true
    remove_column :clients, :client_organization_id
    change_column_null :clients, :client_person_id, false
    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_client_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id
          OR NEW.client_reference IS DISTINCT FROM OLD.client_reference THEN
          RAISE EXCEPTION 'client identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    drop_table :client_organization_websites
    drop_table :client_organization_postal_addresses
    drop_table :client_organization_phone_numbers
    drop_table :client_organization_email_addresses
    drop_table :client_organizations
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_client_organization_contact_owner_change();
    SQL
  end

  private

  def create_client_organizations
    create_table :client_organizations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :display_name, null: false
      table.string :legal_name
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index :client_organizations, [ :id, :agency_id ], unique: true, name: "index_client_organizations_on_id_and_agency_id"
    add_check_constraint :client_organizations, "status IN ('active', 'inactive')", name: "client_organizations_status"
    add_check_constraint :client_organizations, "btrim(display_name) <> ''", name: "client_organizations_display_name_present"
    add_check_constraint :client_organizations, "lock_version >= 0", name: "client_organizations_lock_version"

    execute <<~SQL
      ALTER TABLE client_organizations
        ADD COLUMN display_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(display_name)) STORED,
        ADD COLUMN legal_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(legal_name)) STORED,
        ADD COLUMN name_search_vector tsvector
          GENERATED ALWAYS AS (
            to_tsvector(
              'simple',
              coalesce(dd_search_normalize(display_name), '') || ' ' || coalesce(dd_search_normalize(legal_name), '')
            )
          ) STORED;

      CREATE TRIGGER client_organizations_reject_agency_id_change
      BEFORE UPDATE ON client_organizations
      FOR EACH ROW EXECUTE FUNCTION reject_directory_agency_change();
    SQL
    add_index :client_organizations, [ :agency_id, :display_name_search_key ],
      name: "index_client_organizations_on_agency_and_display_name_key"
    add_index :client_organizations, [ :agency_id, :legal_name_search_key ],
      name: "index_client_organizations_on_agency_and_legal_name_key"
    add_index :client_organizations, :name_search_vector,
      using: :gin,
      name: "index_client_organizations_on_name_search_vector"
  end

  def create_organization_contact_points
    execute <<~SQL
      CREATE FUNCTION reject_client_organization_contact_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id THEN
          RAISE EXCEPTION 'contact-point owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    create_org_contact_point_table(:client_organization_email_addresses)
    add_column :client_organization_email_addresses, :address, :string, null: false
    execute <<~SQL
      ALTER TABLE client_organization_email_addresses
        ADD COLUMN normalized_address text
          GENERATED ALWAYS AS (lower(btrim(address))) STORED;
    SQL
    add_check_constraint :client_organization_email_addresses,
      "normalized_address = lower(btrim(address)) AND normalized_address <> ''",
      name: "client_organization_email_addresses_normalized"
    add_index :client_organization_email_addresses, [ :agency_id, :normalized_address ],
      name: "index_client_org_emails_on_agency_and_normalized"

    create_org_contact_point_table(:client_organization_phone_numbers)
    add_column :client_organization_phone_numbers, :number, :string, null: false
    add_column :client_organization_phone_numbers, :normalized_number, :string, null: false
    add_column :client_organization_phone_numbers, :extension, :string
    add_column :client_organization_phone_numbers, :country_code, :string, null: false
    add_check_constraint :client_organization_phone_numbers,
      "normalized_number ~ '^\\+[1-9][0-9]{0,14}$'",
      name: "client_organization_phone_numbers_e164_shape"
    add_check_constraint :client_organization_phone_numbers,
      "extension IS NULL OR extension ~ '^[0-9]{1,10}$'",
      name: "client_organization_phone_numbers_extension"
    add_check_constraint :client_organization_phone_numbers,
      "country_code ~ '^[A-Z]{2}$'",
      name: "client_organization_phone_numbers_country_shape"
    execute <<~SQL
      ALTER TABLE client_organization_phone_numbers
        ADD COLUMN phone_digits_reversed text
          GENERATED ALWAYS AS (reverse(substring(normalized_number from 2))) STORED;
    SQL
    add_index :client_organization_phone_numbers, [ :agency_id, :normalized_number ],
      name: "index_client_org_phones_on_agency_and_e164"
    add_index :client_organization_phone_numbers, [ :agency_id, :phone_digits_reversed ],
      name: "index_client_org_phones_on_agency_and_reversed_digits",
      opclass: { phone_digits_reversed: :text_pattern_ops }

    create_org_contact_point_table(:client_organization_postal_addresses)
    add_column :client_organization_postal_addresses, :line_1, :string, null: false
    add_column :client_organization_postal_addresses, :line_2, :string
    add_column :client_organization_postal_addresses, :locality, :string
    add_column :client_organization_postal_addresses, :region, :string
    add_column :client_organization_postal_addresses, :postal_code, :string
    add_column :client_organization_postal_addresses, :country_code, :string, null: false
    add_check_constraint :client_organization_postal_addresses, "btrim(line_1) <> ''",
      name: "client_organization_postal_addresses_line_1"
    add_check_constraint :client_organization_postal_addresses, "country_code ~ '^[A-Z]{2}$'",
      name: "client_organization_postal_addresses_country_shape"
    execute <<~SQL
      ALTER TABLE client_organization_postal_addresses
        ADD COLUMN postal_code_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(postal_code)) STORED,
        ADD COLUMN locality_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(locality)) STORED;
    SQL
    add_index :client_organization_postal_addresses, [ :agency_id, :postal_code_search_key ],
      name: "index_client_org_postals_on_agency_and_postal_code"
    add_index :client_organization_postal_addresses, [ :agency_id, :locality_search_key ],
      name: "index_client_org_postals_on_agency_and_locality",
      opclass: { locality_search_key: :text_pattern_ops }

    create_org_contact_point_table(:client_organization_websites)
    add_column :client_organization_websites, :url, :string, null: false
    add_column :client_organization_websites, :normalized_url, :string, null: false
    add_column :client_organization_websites, :normalized_host, :string, null: false
    add_check_constraint :client_organization_websites, "btrim(url) <> ''",
      name: "client_organization_websites_url_present"
    add_check_constraint :client_organization_websites, "btrim(normalized_url) <> ''",
      name: "client_organization_websites_normalized_url_present"
    add_check_constraint :client_organization_websites, "btrim(normalized_host) <> ''",
      name: "client_organization_websites_normalized_host_present"
    add_index :client_organization_websites, [ :agency_id, :normalized_host ],
      name: "index_client_org_websites_on_agency_and_host"
  end

  def widen_clients
    change_column_null :clients, :client_person_id, true
    add_column :clients, :client_organization_id, :uuid

    bad_count = select_value(<<~SQL)
      SELECT count(*)
      FROM clients
      WHERE num_nonnulls(client_person_id, client_organization_id) <> 1
    SQL
    raise "existing clients must have exactly one source before enforcing XOR" if bad_count.to_i.positive?

    add_index :clients, :client_organization_id,
      unique: true,
      where: "client_organization_id IS NOT NULL",
      name: "index_clients_on_client_organization_id"
    add_foreign_key :clients, :client_organizations,
      column: [ :client_organization_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "clients_organization_agency_fk"
    add_check_constraint :clients,
      "num_nonnulls(client_person_id, client_organization_id) = 1",
      name: "clients_exactly_one_source"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION reject_client_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id
          OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
          OR NEW.client_reference IS DISTINCT FROM OLD.client_reference THEN
          RAISE EXCEPTION 'client identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def create_organization_contacts
    create_table :client_organization_contacts, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :client_organization_id, null: false
      table.uuid :client_person_id, null: false
      table.date :starts_on, null: false
      table.date :ends_on
      table.string :title
      table.string :role_label
      table.boolean :primary, null: false, default: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :client_organization_contacts, [ :id, :agency_id ],
      unique: true,
      name: "index_client_organization_contacts_on_id_and_agency_id"
    add_index :client_organization_contacts, [ :client_organization_id, :agency_id ],
      name: "index_client_org_contacts_on_organization_and_agency"
    add_index :client_organization_contacts, [ :client_person_id, :agency_id ],
      name: "index_client_org_contacts_on_person_and_agency"
    add_foreign_key :client_organization_contacts, :client_organizations,
      column: [ :client_organization_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "client_org_contacts_organization_agency_fk"
    add_foreign_key :client_organization_contacts, :client_people,
      column: [ :client_person_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "client_org_contacts_person_agency_fk"

    add_check_constraint :client_organization_contacts,
      "ends_on IS NULL OR ends_on >= starts_on",
      name: "client_org_contacts_date_order"
    add_check_constraint :client_organization_contacts,
      "lock_version >= 0",
      name: "client_org_contacts_lock_version"

    add_index :client_organization_contacts,
      [ :agency_id, :client_organization_id, :client_person_id ],
      unique: true,
      where: "ends_on IS NULL",
      name: "index_client_org_contacts_one_current_pair"
    add_index :client_organization_contacts,
      [ :agency_id, :client_organization_id ],
      unique: true,
      where: "ends_on IS NULL AND \"primary\"",
      name: "index_client_org_contacts_one_current_primary"

    execute <<~SQL
      CREATE FUNCTION reject_client_organization_contact_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_organization_id IS DISTINCT FROM OLD.client_organization_id
          OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id THEN
          RAISE EXCEPTION 'organization contact identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER client_organization_contacts_reject_identity_change
      BEFORE UPDATE ON client_organization_contacts
      FOR EACH ROW EXECUTE FUNCTION reject_client_organization_contact_identity_change();

      ALTER TABLE client_organization_contacts
        ADD CONSTRAINT client_org_contacts_no_overlapping_history
        EXCLUDE USING gist (
          agency_id WITH =,
          client_organization_id WITH =,
          client_person_id WITH =,
          daterange(
            starts_on,
            COALESCE(ends_on + 1, 'infinity'::date),
            '[)'
          ) WITH &&
        );
    SQL
  end

  def create_org_contact_point_table(name)
    name = name.to_s
    short = name.sub("client_organization_", "client_org_")
    create_table name, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :client_organization_id, null: false
      table.string :label, limit: 40
      table.string :status, null: false, default: "active"
      table.boolean :preferred, null: false, default: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index name, [ :id, :agency_id ], unique: true, name: "index_#{short}_on_id_and_agency_id"
    add_index name, [ :client_organization_id, :agency_id ], name: "index_#{short}_on_organization_and_agency"
    add_foreign_key name, :client_organizations,
      column: [ :client_organization_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{short}_organization_agency_fk"
    add_index name, [ :agency_id, :client_organization_id ],
      unique: true,
      where: "preferred AND status = 'active'",
      name: "index_#{short}_on_one_preferred_active"
    add_check_constraint name, "status IN ('active', 'inactive')", name: "#{short}_status"
    add_check_constraint name, "lock_version >= 0", name: "#{short}_lock_version"
    add_check_constraint name, "label IS NULL OR char_length(label) <= 40", name: "#{short}_label_length"
    execute <<~SQL
      CREATE TRIGGER #{short}_reject_owner_change
      BEFORE UPDATE ON #{name}
      FOR EACH ROW EXECUTE FUNCTION reject_client_organization_contact_owner_change();
    SQL
  end
end
