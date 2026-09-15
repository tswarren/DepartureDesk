class CreateSupplierLocationsAndContacts < ActiveRecord::Migration[8.1]
  UNIT_SEPARATOR = "E'\\x1F'".freeze

  def up
    create_supplier_locations
    create_supplier_contacts
    create_supplier_contact_owned_destinations
  end

  def down
    drop_table :supplier_contact_phone_numbers
    drop_table :supplier_contact_email_addresses
    drop_table :supplier_contacts
    drop_table :supplier_locations
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_supplier_location_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_contact_person_owner_change();
      DROP FUNCTION IF EXISTS reject_supplier_contact_destination_owner_change();
    SQL
  end

  private

  def create_supplier_locations
    create_table :supplier_locations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_id, null: false
      table.string :name, null: false, limit: 160
      table.string :timezone
      table.string :address_line_1
      table.string :address_line_2
      table.string :address_locality
      table.string :address_region
      table.string :address_postal_code
      table.string :address_country_code
      table.string :phone_number
      table.string :phone_normalized_number
      table.string :phone_extension
      table.string :phone_country_code
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_locations, [ :id, :agency_id ],
      unique: true,
      name: "index_supplier_locations_on_id_and_agency_id"
    add_index :supplier_locations, [ :supplier_id, :agency_id ],
      name: "index_supplier_locations_on_supplier_and_agency"
    add_index :supplier_locations, [ :agency_id, :supplier_id, :status ],
      name: "index_supplier_locations_on_agency_supplier_status"
    add_foreign_key :supplier_locations, :suppliers,
      column: [ :supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_locations_supplier_agency_fk"

    add_check_constraint :supplier_locations, "status IN ('active', 'inactive')",
      name: "supplier_locations_status"
    add_check_constraint :supplier_locations, "lock_version >= 0",
      name: "supplier_locations_lock_version"
    add_check_constraint :supplier_locations,
      "btrim(name) <> '' AND char_length(name) <= 160",
      name: "supplier_locations_name"
    add_check_constraint :supplier_locations, <<~SQL.squish, name: "supplier_locations_postal_shape"
      (
        address_line_1 IS NULL
        AND address_line_2 IS NULL
        AND address_locality IS NULL
        AND address_region IS NULL
        AND address_postal_code IS NULL
        AND address_country_code IS NULL
      ) OR (
        address_line_1 IS NOT NULL
        AND btrim(address_line_1) <> ''
        AND address_country_code IS NOT NULL
        AND address_country_code ~ '^[A-Z]{2}$'
      )
    SQL
    add_check_constraint :supplier_locations, <<~SQL.squish, name: "supplier_locations_phone_shape"
      (
        phone_number IS NULL
        AND phone_normalized_number IS NULL
        AND phone_extension IS NULL
        AND phone_country_code IS NULL
      ) OR (
        phone_number IS NOT NULL
        AND btrim(phone_number) <> ''
        AND phone_normalized_number IS NOT NULL
        AND phone_normalized_number ~ '^\\+[1-9][0-9]{0,14}$'
        AND phone_country_code IS NOT NULL
        AND phone_country_code ~ '^[A-Z]{2}$'
        AND (phone_extension IS NULL OR phone_extension ~ '^[0-9]{1,10}$')
      )
    SQL
    add_check_constraint :supplier_locations, <<~SQL.squish, name: "supplier_locations_no_unit_separator"
      (address_line_1 IS NULL OR position(#{UNIT_SEPARATOR} in address_line_1) = 0)
      AND (address_line_2 IS NULL OR position(#{UNIT_SEPARATOR} in address_line_2) = 0)
      AND (address_locality IS NULL OR position(#{UNIT_SEPARATOR} in address_locality) = 0)
      AND (address_region IS NULL OR position(#{UNIT_SEPARATOR} in address_region) = 0)
      AND (address_postal_code IS NULL OR position(#{UNIT_SEPARATOR} in address_postal_code) = 0)
    SQL

    postal_key = <<~SQL.squish
      CASE
        WHEN address_line_1 IS NULL THEN NULL
        ELSE
          coalesce(dd_search_normalize(address_line_1), '') || #{UNIT_SEPARATOR} ||
          coalesce(dd_search_normalize(address_line_2), '') || #{UNIT_SEPARATOR} ||
          coalesce(dd_search_normalize(address_locality), '') || #{UNIT_SEPARATOR} ||
          coalesce(dd_search_normalize(address_region), '') || #{UNIT_SEPARATOR} ||
          coalesce(dd_search_normalize(address_postal_code), '') || #{UNIT_SEPARATOR} ||
          coalesce(upper(address_country_code), '')
      END
    SQL

    execute <<~SQL
      ALTER TABLE supplier_locations
        ADD COLUMN name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(name)) STORED,
        ADD COLUMN locality_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(address_locality)) STORED,
        ADD COLUMN postal_code_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(address_postal_code)) STORED,
        ADD COLUMN postal_address_search_key text
          GENERATED ALWAYS AS (#{postal_key}) STORED;

      CREATE FUNCTION reject_supplier_location_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
          RAISE EXCEPTION 'supplier location owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_locations_reject_owner_change
      BEFORE UPDATE ON supplier_locations
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_location_owner_change();
    SQL

    add_index :supplier_locations, [ :agency_id, :name_search_key ],
      name: "index_supplier_locations_on_agency_and_name_key"
    add_index :supplier_locations, [ :agency_id, :locality_search_key ],
      name: "index_supplier_locations_on_agency_and_locality",
      opclass: { locality_search_key: :text_pattern_ops }
    add_index :supplier_locations, [ :agency_id, :postal_code_search_key ],
      name: "index_supplier_locations_on_agency_and_postal_code"
    add_index :supplier_locations, [ :agency_id, :supplier_id, :postal_address_search_key ],
      name: "index_supplier_locations_on_agency_supplier_postal_key"
  end

  def create_supplier_contacts
    create_table :supplier_contacts, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_id, null: false
      table.string :first_name, null: false, limit: 100
      table.string :last_name, null: false, limit: 100
      table.string :title, limit: 120
      table.string :department, limit: 120
      table.string :role_label, limit: 80
      table.boolean :preferred, null: false, default: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_contacts, [ :id, :agency_id ],
      unique: true,
      name: "index_supplier_contacts_on_id_and_agency_id"
    add_index :supplier_contacts, [ :supplier_id, :agency_id ],
      name: "index_supplier_contacts_on_supplier_and_agency"
    add_index :supplier_contacts, [ :agency_id, :supplier_id, :status ],
      name: "index_supplier_contacts_on_agency_supplier_status"
    add_index :supplier_contacts, [ :agency_id, :supplier_id ],
      unique: true,
      where: "preferred AND status = 'active'",
      name: "index_supplier_contacts_on_one_preferred_active"
    add_foreign_key :supplier_contacts, :suppliers,
      column: [ :supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_contacts_supplier_agency_fk"

    add_check_constraint :supplier_contacts, "status IN ('active', 'inactive')",
      name: "supplier_contacts_status"
    add_check_constraint :supplier_contacts, "lock_version >= 0",
      name: "supplier_contacts_lock_version"
    add_check_constraint :supplier_contacts,
      "btrim(first_name) <> '' AND char_length(first_name) <= 100",
      name: "supplier_contacts_first_name"
    add_check_constraint :supplier_contacts,
      "btrim(last_name) <> '' AND char_length(last_name) <= 100",
      name: "supplier_contacts_last_name"
    add_check_constraint :supplier_contacts,
      "title IS NULL OR (btrim(title) <> '' AND char_length(title) <= 120)",
      name: "supplier_contacts_title"
    add_check_constraint :supplier_contacts,
      "department IS NULL OR (btrim(department) <> '' AND char_length(department) <= 120)",
      name: "supplier_contacts_department"
    add_check_constraint :supplier_contacts,
      "role_label IS NULL OR (btrim(role_label) <> '' AND char_length(role_label) <= 80)",
      name: "supplier_contacts_role_label"

    full_name = "dd_search_normalize(first_name || ' ' || last_name)"
    execute <<~SQL
      ALTER TABLE supplier_contacts
        ADD COLUMN first_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(first_name)) STORED,
        ADD COLUMN last_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(last_name)) STORED,
        ADD COLUMN full_name_search_key text
          GENERATED ALWAYS AS (#{full_name}) STORED,
        ADD COLUMN name_search_vector tsvector
          GENERATED ALWAYS AS (to_tsvector('simple', #{full_name})) STORED;

      CREATE FUNCTION reject_supplier_contact_person_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
          RAISE EXCEPTION 'supplier contact owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_contacts_reject_owner_change
      BEFORE UPDATE ON supplier_contacts
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_contact_person_owner_change();
    SQL

    add_index :supplier_contacts, [ :agency_id, :full_name_search_key ],
      name: "index_supplier_contacts_on_agency_and_full_name"
    add_index :supplier_contacts, [ :agency_id, :first_name_search_key, :last_name_search_key ],
      name: "index_supplier_contacts_on_agency_and_name_parts"
    add_index :supplier_contacts, :name_search_vector,
      using: :gin,
      name: "index_supplier_contacts_on_name_search_vector"
  end

  def create_supplier_contact_owned_destinations
    execute <<~SQL
      CREATE FUNCTION reject_supplier_contact_destination_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.supplier_contact_id IS DISTINCT FROM OLD.supplier_contact_id THEN
          RAISE EXCEPTION 'supplier contact destination owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    create_contact_destination_table(:supplier_contact_email_addresses)
    add_column :supplier_contact_email_addresses, :address, :string, null: false
    execute <<~SQL
      ALTER TABLE supplier_contact_email_addresses
        ADD COLUMN normalized_address text
          GENERATED ALWAYS AS (lower(btrim(address))) STORED;
    SQL
    add_check_constraint :supplier_contact_email_addresses,
      "normalized_address = lower(btrim(address)) AND normalized_address <> ''",
      name: "supplier_contact_email_addresses_normalized"
    add_index :supplier_contact_email_addresses, [ :agency_id, :normalized_address ],
      name: "index_supplier_contact_emails_on_agency_and_normalized"

    create_contact_destination_table(:supplier_contact_phone_numbers)
    add_column :supplier_contact_phone_numbers, :number, :string, null: false
    add_column :supplier_contact_phone_numbers, :normalized_number, :string, null: false
    add_column :supplier_contact_phone_numbers, :extension, :string
    add_column :supplier_contact_phone_numbers, :country_code, :string, null: false
    add_check_constraint :supplier_contact_phone_numbers,
      "normalized_number ~ '^\\+[1-9][0-9]{0,14}$'",
      name: "supplier_contact_phone_numbers_e164_shape"
    add_check_constraint :supplier_contact_phone_numbers,
      "extension IS NULL OR extension ~ '^[0-9]{1,10}$'",
      name: "supplier_contact_phone_numbers_extension"
    add_check_constraint :supplier_contact_phone_numbers,
      "country_code ~ '^[A-Z]{2}$'",
      name: "supplier_contact_phone_numbers_country_shape"
    execute <<~SQL
      ALTER TABLE supplier_contact_phone_numbers
        ADD COLUMN phone_digits_reversed text
          GENERATED ALWAYS AS (reverse(substring(normalized_number from 2))) STORED;
    SQL
    add_index :supplier_contact_phone_numbers, [ :agency_id, :normalized_number ],
      name: "index_supplier_contact_phones_on_agency_and_e164"
    add_index :supplier_contact_phone_numbers, [ :agency_id, :phone_digits_reversed ],
      name: "index_supplier_contact_phones_on_agency_and_reversed",
      opclass: { phone_digits_reversed: :text_pattern_ops }
  end

  def create_contact_destination_table(name)
    name = name.to_s
    create_table name, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_contact_id, null: false
      table.string :label, limit: 40
      table.string :status, null: false, default: "active"
      table.boolean :preferred, null: false, default: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index name, [ :id, :agency_id ], unique: true, name: "index_#{name}_on_id_and_agency_id"
    add_index name, [ :supplier_contact_id, :agency_id ],
      name: "index_#{name}_on_contact_and_agency"
    add_foreign_key name, :supplier_contacts,
      column: [ :supplier_contact_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{name}_contact_agency_fk"
    add_index name, [ :agency_id, :supplier_contact_id ],
      unique: true,
      where: "preferred AND status = 'active'",
      name: "index_#{name}_on_one_preferred_active"
    add_check_constraint name, "status IN ('active', 'inactive')", name: "#{name}_status"
    add_check_constraint name, "lock_version >= 0", name: "#{name}_lock_version"
    add_check_constraint name, "label IS NULL OR char_length(label) <= 40", name: "#{name}_label_length"
    execute <<~SQL
      CREATE TRIGGER #{name}_reject_owner_change
      BEFORE UPDATE ON #{name}
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_contact_destination_owner_change();
    SQL
  end
end
