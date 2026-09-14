class CreateIndividualClientDirectory < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION dd_search_normalize(input text)
      RETURNS text
      LANGUAGE sql
      IMMUTABLE
      PARALLEL SAFE
      RETURN regexp_replace(
        btrim(
          normalize(
            casefold((normalize(input, NFKC)) COLLATE "pg_unicode_fast"),
            NFKC
          )
        ),
        '[[:space:]]+',
        ' ',
        'g'
      );

      CREATE FUNCTION reject_directory_agency_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'agency_id is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE FUNCTION reject_client_identity_change() RETURNS trigger
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

      CREATE FUNCTION reject_client_person_contact_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.client_person_id IS DISTINCT FROM OLD.client_person_id THEN
          RAISE EXCEPTION 'contact-point owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    create_table :client_people, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :first_name, null: false
      table.string :middle_name
      table.string :last_name, null: false
      table.string :suffix
      table.string :preferred_name
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index :client_people, [ :id, :agency_id ], unique: true, name: "index_client_people_on_id_and_agency_id"
    add_check_constraint :client_people, "status IN ('active', 'inactive')", name: "client_people_status"
    add_check_constraint :client_people, "btrim(first_name) <> '' AND btrim(last_name) <> ''", name: "client_people_names_present"
    add_check_constraint :client_people, "lock_version >= 0", name: "client_people_lock_version"

    # concat_ws is STABLE on PostgreSQL 18.6, so a generated column cannot call it.
    # Empty-string coalescing plus dd_search_normalize collapses the same gaps.
    name_expression = <<~SQL.squish
      dd_search_normalize(
        first_name || ' ' || coalesce(middle_name, '') || ' ' || last_name || ' ' ||
        coalesce(suffix, '') || ' ' || coalesce(preferred_name, '')
      )
    SQL
    execute <<~SQL
      ALTER TABLE client_people
        ADD COLUMN name_search_key text
          GENERATED ALWAYS AS (#{name_expression}) STORED,
        ADD COLUMN name_search_vector tsvector
          GENERATED ALWAYS AS (to_tsvector('simple', #{name_expression})) STORED;
    SQL
    add_index :client_people, [ :agency_id, :name_search_key ], name: "index_client_people_on_agency_and_name_search_key"
    add_index :client_people, :name_search_vector, using: :gin, name: "index_client_people_on_name_search_vector"

    create_table :clients, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :client_person_id, null: false
      table.string :client_reference, null: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index :clients, [ :id, :agency_id ], unique: true, name: "index_clients_on_id_and_agency_id"
    add_index :clients, :client_person_id, unique: true, name: "index_clients_on_client_person_id"
    add_index :clients, [ :agency_id, :client_reference ], unique: true, name: "index_clients_on_agency_and_reference"
    add_foreign_key :clients, :client_people, column: [ :client_person_id, :agency_id ], primary_key: [ :id, :agency_id ], name: "clients_person_agency_fk"
    add_check_constraint :clients, "status IN ('active', 'inactive')", name: "clients_status"
    add_check_constraint :clients, "client_reference ~ '^CL-[0-9]{6}$'", name: "clients_reference_format"
    add_check_constraint :clients, "lock_version >= 0", name: "clients_lock_version"

    create_contact_point_table(:client_person_email_addresses)
    add_column :client_person_email_addresses, :address, :string, null: false
    execute <<~SQL
      ALTER TABLE client_person_email_addresses
        ADD COLUMN normalized_address text
          GENERATED ALWAYS AS (lower(btrim(address))) STORED;
    SQL
    add_check_constraint :client_person_email_addresses,
      "normalized_address = lower(btrim(address)) AND normalized_address <> ''",
      name: "client_person_email_addresses_normalized"
    add_index :client_person_email_addresses, [ :agency_id, :normalized_address ], name: "index_client_person_emails_on_agency_and_normalized"

    create_contact_point_table(:client_person_phone_numbers)
    add_column :client_person_phone_numbers, :number, :string, null: false
    add_column :client_person_phone_numbers, :normalized_number, :string, null: false
    add_column :client_person_phone_numbers, :extension, :string
    add_column :client_person_phone_numbers, :country_code, :string, null: false
    add_check_constraint :client_person_phone_numbers,
      "normalized_number ~ '^\\+[1-9][0-9]{0,14}$'",
      name: "client_person_phone_numbers_e164_shape"
    add_check_constraint :client_person_phone_numbers,
      "extension IS NULL OR extension ~ '^[0-9]{1,10}$'",
      name: "client_person_phone_numbers_extension"
    add_check_constraint :client_person_phone_numbers,
      "country_code ~ '^[A-Z]{2}$'",
      name: "client_person_phone_numbers_country_shape"
    execute <<~SQL
      ALTER TABLE client_person_phone_numbers
        ADD COLUMN phone_digits_reversed text
          GENERATED ALWAYS AS (reverse(substring(normalized_number from 2))) STORED;
    SQL
    add_index :client_person_phone_numbers, [ :agency_id, :normalized_number ], name: "index_client_person_phones_on_agency_and_e164"
    add_index :client_person_phone_numbers, [ :agency_id, :phone_digits_reversed ],
      name: "index_client_person_phones_on_agency_and_reversed_digits",
      opclass: { phone_digits_reversed: :text_pattern_ops }

    create_contact_point_table(:client_person_postal_addresses)
    add_column :client_person_postal_addresses, :line_1, :string, null: false
    add_column :client_person_postal_addresses, :line_2, :string
    add_column :client_person_postal_addresses, :locality, :string
    add_column :client_person_postal_addresses, :region, :string
    add_column :client_person_postal_addresses, :postal_code, :string
    add_column :client_person_postal_addresses, :country_code, :string, null: false
    add_check_constraint :client_person_postal_addresses, "btrim(line_1) <> ''", name: "client_person_postal_addresses_line_1"
    add_check_constraint :client_person_postal_addresses, "country_code ~ '^[A-Z]{2}$'", name: "client_person_postal_addresses_country_shape"
    execute <<~SQL
      ALTER TABLE client_person_postal_addresses
        ADD COLUMN postal_code_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(postal_code)) STORED,
        ADD COLUMN locality_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(locality)) STORED;
    SQL
    add_index :client_person_postal_addresses, [ :agency_id, :postal_code_search_key ], name: "index_client_person_postals_on_agency_and_postal_code"
    add_index :client_person_postal_addresses, [ :agency_id, :locality_search_key ],
      name: "index_client_person_postals_on_agency_and_locality",
      opclass: { locality_search_key: :text_pattern_ops }

    create_table :reference_sequences, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :namespace, null: false
      table.bigint :next_value, null: false, default: 1
      table.timestamps null: false
    end
    add_index :reference_sequences, [ :agency_id, :namespace ], unique: true, name: "index_reference_sequences_on_agency_and_namespace"
    add_check_constraint :reference_sequences, "namespace = 'client'", name: "reference_sequences_namespace"
    add_check_constraint :reference_sequences, "next_value >= 1 AND next_value <= 1000000", name: "reference_sequences_next_value"

    execute <<~SQL
      INSERT INTO reference_sequences (id, agency_id, namespace, next_value, created_at, updated_at)
      SELECT uuidv7(), agencies.id, 'client', 1, now(), now()
      FROM agencies;

      CREATE TRIGGER client_people_reject_agency_id_change
      BEFORE UPDATE ON client_people
      FOR EACH ROW EXECUTE FUNCTION reject_directory_agency_change();

      CREATE TRIGGER clients_reject_identity_change
      BEFORE UPDATE ON clients
      FOR EACH ROW EXECUTE FUNCTION reject_client_identity_change();

      CREATE TRIGGER client_person_email_addresses_reject_owner_change
      BEFORE UPDATE ON client_person_email_addresses
      FOR EACH ROW EXECUTE FUNCTION reject_client_person_contact_owner_change();

      CREATE TRIGGER client_person_phone_numbers_reject_owner_change
      BEFORE UPDATE ON client_person_phone_numbers
      FOR EACH ROW EXECUTE FUNCTION reject_client_person_contact_owner_change();

      CREATE TRIGGER client_person_postal_addresses_reject_owner_change
      BEFORE UPDATE ON client_person_postal_addresses
      FOR EACH ROW EXECUTE FUNCTION reject_client_person_contact_owner_change();

      CREATE FUNCTION reject_reference_sequence_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.namespace IS DISTINCT FROM OLD.namespace THEN
          RAISE EXCEPTION 'reference sequence identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER reference_sequences_reject_identity_change
      BEFORE UPDATE ON reference_sequences
      FOR EACH ROW EXECUTE FUNCTION reject_reference_sequence_identity_change();
    SQL
  end

  def down
    drop_table :reference_sequences
    drop_table :client_person_postal_addresses
    drop_table :client_person_phone_numbers
    drop_table :client_person_email_addresses
    drop_table :clients
    drop_table :client_people
    execute <<~SQL
      DROP FUNCTION reject_client_person_contact_owner_change();
      DROP FUNCTION reject_client_identity_change();
      DROP FUNCTION reject_reference_sequence_identity_change();
      DROP FUNCTION reject_directory_agency_change();
      DROP FUNCTION dd_search_normalize(text);
    SQL
  end

  private

  def create_contact_point_table(name)
    create_table name, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :client_person_id, null: false
      table.string :label, limit: 40
      table.string :status, null: false, default: "active"
      table.boolean :preferred, null: false, default: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index name, [ :id, :agency_id ], unique: true, name: "index_#{name}_on_id_and_agency_id"
    add_index name, [ :client_person_id, :agency_id ], name: "index_#{name}_on_person_and_agency"
    add_foreign_key name, :client_people, column: [ :client_person_id, :agency_id ], primary_key: [ :id, :agency_id ], name: "#{name}_person_agency_fk"
    add_index name, [ :agency_id, :client_person_id ],
      unique: true,
      where: "preferred AND status = 'active'",
      name: "index_#{name}_on_one_preferred_active"
    add_check_constraint name, "status IN ('active', 'inactive')", name: "#{name}_status"
    add_check_constraint name, "lock_version >= 0", name: "#{name}_lock_version"
    add_check_constraint name, "label IS NULL OR char_length(label) <= 40", name: "#{name}_label_length"
  end
end
