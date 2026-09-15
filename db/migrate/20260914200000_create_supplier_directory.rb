class CreateSupplierDirectory < ActiveRecord::Migration[8.1]
  CATEGORY_CODES = %w[
    cruise_line
    lodging
    air
    ground_transportation
    tour_operator_dmc
    dining
    activity_attraction
    insurance
    other
  ].freeze

  def up
    widen_reference_sequences
    create_suppliers
    create_supplier_category_assignments
    create_supplier_contact_points
  end

  def down
    drop_table :supplier_websites
    drop_table :supplier_postal_addresses
    drop_table :supplier_phone_numbers
    drop_table :supplier_email_addresses
    drop_table :supplier_category_assignments
    drop_table :suppliers
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_supplier_identity_change();
      DROP FUNCTION IF EXISTS reject_supplier_category_identity_change();
      DROP FUNCTION IF EXISTS reject_supplier_contact_owner_change();
    SQL

    remove_check_constraint :reference_sequences, name: "reference_sequences_namespace"
    add_check_constraint :reference_sequences, "namespace = 'client'", name: "reference_sequences_namespace"
    execute "DELETE FROM reference_sequences WHERE namespace = 'supplier'"
  end

  private

  def widen_reference_sequences
    remove_check_constraint :reference_sequences, name: "reference_sequences_namespace"
    add_check_constraint :reference_sequences,
      "namespace IN ('client', 'supplier')",
      name: "reference_sequences_namespace"

    execute <<~SQL
      INSERT INTO reference_sequences (id, agency_id, namespace, next_value, created_at, updated_at)
      SELECT uuidv7(), agencies.id, 'supplier', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM agencies
      WHERE NOT EXISTS (
        SELECT 1 FROM reference_sequences
        WHERE reference_sequences.agency_id = agencies.id
          AND reference_sequences.namespace = 'supplier'
      );
    SQL
  end

  def create_suppliers
    create_table :suppliers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.string :kind, null: false
      table.string :supplier_reference, null: false, limit: 10
      table.string :display_name
      table.string :legal_name
      table.string :first_name
      table.string :last_name
      table.string :doing_business_as
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :suppliers, [ :id, :agency_id ], unique: true, name: "index_suppliers_on_id_and_agency_id"
    add_index :suppliers, [ :agency_id, :supplier_reference ], unique: true, name: "index_suppliers_on_agency_and_reference"
    add_check_constraint :suppliers, "kind IN ('organization', 'individual')", name: "suppliers_kind"
    add_check_constraint :suppliers, "status IN ('active', 'inactive')", name: "suppliers_status"
    add_check_constraint :suppliers, "lock_version >= 0", name: "suppliers_lock_version"
    add_check_constraint :suppliers, "supplier_reference ~ '^SUP-[0-9]{6}$'", name: "suppliers_reference_format"
    add_check_constraint :suppliers, <<~SQL.squish, name: "suppliers_name_shape"
      (
        kind = 'organization'
        AND display_name IS NOT NULL AND btrim(display_name) <> ''
        AND first_name IS NULL
        AND last_name IS NULL
      ) OR (
        kind = 'individual'
        AND first_name IS NOT NULL AND btrim(first_name) <> ''
        AND last_name IS NOT NULL AND btrim(last_name) <> ''
        AND display_name IS NULL
        AND legal_name IS NULL
      )
    SQL

    execute <<~SQL
      ALTER TABLE suppliers
        ADD COLUMN display_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(display_name)) STORED,
        ADD COLUMN legal_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(legal_name)) STORED,
        ADD COLUMN first_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(first_name)) STORED,
        ADD COLUMN last_name_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(last_name)) STORED,
        ADD COLUMN doing_business_as_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(doing_business_as)) STORED,
        ADD COLUMN individual_full_name_search_key text
          GENERATED ALWAYS AS (
            CASE
              WHEN kind = 'individual' THEN dd_search_normalize(first_name || ' ' || last_name)
              ELSE NULL
            END
          ) STORED,
        ADD COLUMN name_search_vector tsvector
          GENERATED ALWAYS AS (
            to_tsvector(
              'simple',
              coalesce(dd_search_normalize(display_name), '') || ' ' ||
              coalesce(dd_search_normalize(legal_name), '') || ' ' ||
              coalesce(dd_search_normalize(first_name), '') || ' ' ||
              coalesce(dd_search_normalize(last_name), '') || ' ' ||
              coalesce(dd_search_normalize(doing_business_as), '')
            )
          ) STORED;

      CREATE FUNCTION reject_supplier_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.kind IS DISTINCT FROM OLD.kind
          OR NEW.supplier_reference IS DISTINCT FROM OLD.supplier_reference THEN
          RAISE EXCEPTION 'supplier identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER suppliers_reject_identity_change
      BEFORE UPDATE ON suppliers
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_identity_change();
    SQL

    add_index :suppliers, [ :agency_id, :display_name_search_key ], name: "index_suppliers_on_agency_and_display_name_key"
    add_index :suppliers, [ :agency_id, :legal_name_search_key ], name: "index_suppliers_on_agency_and_legal_name_key"
    add_index :suppliers, [ :agency_id, :doing_business_as_search_key ], name: "index_suppliers_on_agency_and_dba_key"
    add_index :suppliers, [ :agency_id, :individual_full_name_search_key ], name: "index_suppliers_on_agency_and_individual_name_key"
    add_index :suppliers, :name_search_vector, using: :gin, name: "index_suppliers_on_name_search_vector"
    add_index :suppliers, [ :agency_id, :kind, :status ], name: "index_suppliers_on_agency_kind_status"
  end

  def create_supplier_category_assignments
    codes_sql = CATEGORY_CODES.map { |code| "'#{code}'" }.join(", ")

    create_table :supplier_category_assignments, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_id, null: false
      table.string :category_code, null: false
      table.string :other_label, limit: 80
      table.timestamps null: false
    end

    add_index :supplier_category_assignments, [ :id, :agency_id ],
      unique: true,
      name: "index_supplier_category_assignments_on_id_and_agency_id"
    add_index :supplier_category_assignments, [ :agency_id, :supplier_id, :category_code ],
      unique: true,
      name: "index_supplier_category_assignments_on_agency_supplier_code"
    add_index :supplier_category_assignments, [ :agency_id, :category_code ],
      name: "index_supplier_category_assignments_on_agency_and_code"
    add_foreign_key :supplier_category_assignments, :suppliers,
      column: [ :supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "supplier_category_assignments_supplier_agency_fk"
    add_check_constraint :supplier_category_assignments,
      "category_code IN (#{codes_sql})",
      name: "supplier_category_assignments_code"
    add_check_constraint :supplier_category_assignments, <<~SQL.squish, name: "supplier_category_assignments_other_label"
      (
        category_code = 'other'
        AND other_label IS NOT NULL
        AND btrim(other_label) <> ''
        AND char_length(other_label) <= 80
      ) OR (
        category_code <> 'other'
        AND other_label IS NULL
      )
    SQL

    execute <<~SQL
      CREATE FUNCTION reject_supplier_category_identity_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id
          OR NEW.category_code IS DISTINCT FROM OLD.category_code THEN
          RAISE EXCEPTION 'supplier category assignment identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_category_assignments_reject_identity_change
      BEFORE UPDATE ON supplier_category_assignments
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_category_identity_change();
    SQL
  end

  def create_supplier_contact_points
    execute <<~SQL
      CREATE FUNCTION reject_supplier_contact_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.supplier_id IS DISTINCT FROM OLD.supplier_id THEN
          RAISE EXCEPTION 'contact-point owner is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL

    create_supplier_contact_point_table(:supplier_email_addresses)
    add_column :supplier_email_addresses, :address, :string, null: false
    execute <<~SQL
      ALTER TABLE supplier_email_addresses
        ADD COLUMN normalized_address text
          GENERATED ALWAYS AS (lower(btrim(address))) STORED;
    SQL
    add_check_constraint :supplier_email_addresses,
      "normalized_address = lower(btrim(address)) AND normalized_address <> ''",
      name: "supplier_email_addresses_normalized"
    add_index :supplier_email_addresses, [ :agency_id, :normalized_address ],
      name: "index_supplier_emails_on_agency_and_normalized"

    create_supplier_contact_point_table(:supplier_phone_numbers)
    add_column :supplier_phone_numbers, :number, :string, null: false
    add_column :supplier_phone_numbers, :normalized_number, :string, null: false
    add_column :supplier_phone_numbers, :extension, :string
    add_column :supplier_phone_numbers, :country_code, :string, null: false
    add_check_constraint :supplier_phone_numbers,
      "normalized_number ~ '^\\+[1-9][0-9]{0,14}$'",
      name: "supplier_phone_numbers_e164_shape"
    add_check_constraint :supplier_phone_numbers,
      "extension IS NULL OR extension ~ '^[0-9]{1,10}$'",
      name: "supplier_phone_numbers_extension"
    add_check_constraint :supplier_phone_numbers,
      "country_code ~ '^[A-Z]{2}$'",
      name: "supplier_phone_numbers_country_shape"
    execute <<~SQL
      ALTER TABLE supplier_phone_numbers
        ADD COLUMN phone_digits_reversed text
          GENERATED ALWAYS AS (reverse(substring(normalized_number from 2))) STORED;
    SQL
    add_index :supplier_phone_numbers, [ :agency_id, :normalized_number ],
      name: "index_supplier_phones_on_agency_and_e164"
    add_index :supplier_phone_numbers, [ :agency_id, :phone_digits_reversed ],
      name: "index_supplier_phones_on_agency_and_reversed_digits",
      opclass: { phone_digits_reversed: :text_pattern_ops }

    create_supplier_contact_point_table(:supplier_postal_addresses)
    add_column :supplier_postal_addresses, :line_1, :string, null: false
    add_column :supplier_postal_addresses, :line_2, :string
    add_column :supplier_postal_addresses, :locality, :string
    add_column :supplier_postal_addresses, :region, :string
    add_column :supplier_postal_addresses, :postal_code, :string
    add_column :supplier_postal_addresses, :country_code, :string, null: false
    add_check_constraint :supplier_postal_addresses, "btrim(line_1) <> ''",
      name: "supplier_postal_addresses_line_1"
    add_check_constraint :supplier_postal_addresses, "country_code ~ '^[A-Z]{2}$'",
      name: "supplier_postal_addresses_country_shape"
    execute <<~SQL
      ALTER TABLE supplier_postal_addresses
        ADD COLUMN postal_code_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(postal_code)) STORED,
        ADD COLUMN locality_search_key text
          GENERATED ALWAYS AS (dd_search_normalize(locality)) STORED;
    SQL
    add_index :supplier_postal_addresses, [ :agency_id, :postal_code_search_key ],
      name: "index_supplier_postals_on_agency_and_postal_code"
    add_index :supplier_postal_addresses, [ :agency_id, :locality_search_key ],
      name: "index_supplier_postals_on_agency_and_locality",
      opclass: { locality_search_key: :text_pattern_ops }

    create_supplier_contact_point_table(:supplier_websites)
    add_column :supplier_websites, :url, :string, null: false
    add_column :supplier_websites, :normalized_url, :string, null: false
    add_column :supplier_websites, :normalized_host, :string, null: false
    add_check_constraint :supplier_websites, "btrim(url) <> ''", name: "supplier_websites_url_present"
    add_check_constraint :supplier_websites, "btrim(normalized_url) <> ''", name: "supplier_websites_normalized_url_present"
    add_check_constraint :supplier_websites, "btrim(normalized_host) <> ''", name: "supplier_websites_normalized_host_present"
    add_index :supplier_websites, [ :agency_id, :normalized_host ],
      name: "index_supplier_websites_on_agency_and_host"
  end

  def create_supplier_contact_point_table(name)
    name = name.to_s
    short = name.sub("supplier_", "supplier_")
    create_table name, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_id, null: false
      table.string :label, limit: 40
      table.string :status, null: false, default: "active"
      table.boolean :preferred, null: false, default: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_index name, [ :id, :agency_id ], unique: true, name: "index_#{short}_on_id_and_agency_id"
    add_index name, [ :supplier_id, :agency_id ], name: "index_#{short}_on_supplier_and_agency"
    add_foreign_key name, :suppliers,
      column: [ :supplier_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{short}_supplier_agency_fk"
    add_index name, [ :agency_id, :supplier_id ],
      unique: true,
      where: "preferred AND status = 'active'",
      name: "index_#{short}_on_one_preferred_active"
    add_check_constraint name, "status IN ('active', 'inactive')", name: "#{short}_status"
    add_check_constraint name, "lock_version >= 0", name: "#{short}_lock_version"
    add_check_constraint name, "label IS NULL OR char_length(label) <= 40", name: "#{short}_label_length"
    execute <<~SQL
      CREATE TRIGGER #{short}_reject_owner_change
      BEFORE UPDATE ON #{name}
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_contact_owner_change();
    SQL
  end
end
