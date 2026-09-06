class CreatePartyContactPoints < ActiveRecord::Migration[8.1]
  def up
    create_table :party_contact_points,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :party_id, null: false
      table.string :contact_kind, null: false
      table.string :label
      table.string :normalized_value, null: false
      table.string :status, null: false, default: "active"
      table.timestamptz :deactivated_at
      table.uuid :deactivated_by_membership_id
      table.string :deactivation_reason
      table.timestamptz :suppressed_at
      table.uuid :suppressed_by_membership_id
      table.string :suppression_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_contact_points,
      [ :id, :agency_id, :contact_kind ],
      unique: true,
      name: "index_party_contact_points_on_id_agency_id_and_kind"
    add_index :party_contact_points,
      [ :party_id, :agency_id ],
      name: "index_party_contact_points_on_party_id_and_agency_id"
    add_index :party_contact_points,
      [ :agency_id, :normalized_value ],
      name: "index_party_contact_points_on_agency_id_and_normalized_value"
    add_index :party_contact_points,
      [ :party_id, :contact_kind, :normalized_value ],
      unique: true,
      where: "status = 'active'",
      name: "index_party_contact_points_unique_active_normalized"

    add_check_constraint :party_contact_points,
      "contact_kind IN ('postal_address', 'phone', 'email')",
      name: "party_contact_points_contact_kind_valid"
    add_check_constraint :party_contact_points,
      "status IN ('active', 'deactivated')",
      name: "party_contact_points_status_valid"
    add_check_constraint :party_contact_points,
      "label IS NULL OR btrim(label) <> ''",
      name: "party_contact_points_label_null_or_not_blank"
    add_check_constraint :party_contact_points,
      "btrim(normalized_value) <> ''",
      name: "party_contact_points_normalized_value_not_blank"
    add_check_constraint :party_contact_points,
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
      name: "party_contact_points_deactivation_matches_status"
    add_check_constraint :party_contact_points,
      <<~SQL.squish,
        (suppressed_at IS NULL
          AND suppressed_by_membership_id IS NULL
          AND suppression_reason IS NULL)
        OR
        (suppressed_at IS NOT NULL
          AND suppressed_by_membership_id IS NOT NULL
          AND btrim(suppression_reason) <> '')
      SQL
      name: "party_contact_points_suppression_complete"
    add_check_constraint :party_contact_points,
      "lock_version >= 0",
      name: "party_contact_points_lock_version_nonnegative"

    execute <<~SQL
      ALTER TABLE party_contact_points
        ADD CONSTRAINT party_contact_points_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE party_contact_points
        ADD CONSTRAINT party_contact_points_deactivated_by_membership_same_agency_fk
        FOREIGN KEY (deactivated_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE party_contact_points
        ADD CONSTRAINT party_contact_points_suppressed_by_membership_same_agency_fk
        FOREIGN KEY (suppressed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL

    execute <<~SQL
      CREATE FUNCTION party_contact_points_prevent_kind_or_agency_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.contact_kind IS DISTINCT FROM OLD.contact_kind THEN
          RAISE EXCEPTION 'contact kind cannot change';
        END IF;
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id THEN
          RAISE EXCEPTION 'contact agency cannot change';
        END IF;
        IF NEW.party_id IS DISTINCT FROM OLD.party_id THEN
          RAISE EXCEPTION 'contact party cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER party_contact_points_kind_agency_party_immutable
        BEFORE UPDATE ON party_contact_points
        FOR EACH ROW
        EXECUTE FUNCTION party_contact_points_prevent_kind_or_agency_change();
    SQL

    create_postal_addresses
    create_phone_numbers
    create_email_addresses
    create_purpose_assignments
  end

  def down
    drop_table :contact_point_purpose_assignments
    drop_table :party_email_addresses
    drop_table :party_phone_numbers
    drop_table :party_postal_addresses
    execute <<~SQL
      DROP TRIGGER IF EXISTS party_contact_points_kind_agency_party_immutable ON party_contact_points;
      DROP FUNCTION IF EXISTS party_contact_points_prevent_kind_or_agency_change();
    SQL
    drop_table :party_contact_points
  end

  private

  def create_postal_addresses
    create_table :party_postal_addresses, id: false, primary_key: :contact_point_id do |table|
      table.uuid :contact_point_id, null: false, primary_key: true
      table.uuid :agency_id, null: false
      table.string :contact_kind, null: false, default: "postal_address"
      table.string :attention
      table.string :address_line_1, null: false
      table.string :address_line_2
      table.string :address_line_3
      table.string :locality
      table.string :administrative_region
      table.string :postal_code
      table.string :country_code, null: false, limit: 2
      table.string :formatted_address, null: false
      table.string :normalized_address, null: false
      table.integer :normalization_version, null: false, default: 1
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_postal_addresses,
      [ :contact_point_id, :agency_id ],
      unique: true,
      name: "index_party_postal_addresses_on_contact_point_and_agency"
    add_check_constraint :party_postal_addresses,
      "contact_kind = 'postal_address'",
      name: "party_postal_addresses_contact_kind_postal_address"
    add_check_constraint :party_postal_addresses,
      "btrim(address_line_1) <> ''",
      name: "party_postal_addresses_address_line_1_not_blank"
    add_check_constraint :party_postal_addresses,
      "country_code ~ '^[A-Z]{2}$'",
      name: "party_postal_addresses_country_code_format"
    add_check_constraint :party_postal_addresses,
      "lock_version >= 0",
      name: "party_postal_addresses_lock_version_nonnegative"
    add_foreign_key :party_postal_addresses, :agencies

    execute <<~SQL
      ALTER TABLE party_postal_addresses
        ADD CONSTRAINT party_postal_addresses_contact_kind_same_agency_fk
        FOREIGN KEY (contact_point_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, agency_id, contact_kind);
    SQL
  end

  def create_phone_numbers
    create_table :party_phone_numbers, id: false, primary_key: :contact_point_id do |table|
      table.uuid :contact_point_id, null: false, primary_key: true
      table.uuid :agency_id, null: false
      table.string :contact_kind, null: false, default: "phone"
      table.string :display_number, null: false
      table.string :normalized_digits, null: false
      table.string :e164_number
      table.string :extension
      table.string :phone_type, null: false
      table.string :parsed_country_code, limit: 2
      table.string :parse_status, null: false
      table.integer :normalization_version, null: false, default: 1
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_phone_numbers,
      [ :contact_point_id, :agency_id ],
      unique: true,
      name: "index_party_phone_numbers_on_contact_point_and_agency"
    add_check_constraint :party_phone_numbers,
      "contact_kind = 'phone'",
      name: "party_phone_numbers_contact_kind_phone"
    add_check_constraint :party_phone_numbers,
      "btrim(display_number) <> ''",
      name: "party_phone_numbers_display_number_not_blank"
    add_check_constraint :party_phone_numbers,
      "btrim(normalized_digits) <> ''",
      name: "party_phone_numbers_normalized_digits_not_blank"
    add_check_constraint :party_phone_numbers,
      "phone_type IN ('mobile', 'home', 'work', 'main', 'fax', 'other')",
      name: "party_phone_numbers_phone_type_valid"
    add_check_constraint :party_phone_numbers,
      "parse_status IN ('valid', 'possible', 'unparsed')",
      name: "party_phone_numbers_parse_status_valid"
    add_check_constraint :party_phone_numbers,
      "parsed_country_code IS NULL OR parsed_country_code ~ '^[A-Z]{2}$'",
      name: "party_phone_numbers_parsed_country_code_format"
    add_check_constraint :party_phone_numbers,
      "lock_version >= 0",
      name: "party_phone_numbers_lock_version_nonnegative"
    add_foreign_key :party_phone_numbers, :agencies

    execute <<~SQL
      ALTER TABLE party_phone_numbers
        ADD CONSTRAINT party_phone_numbers_contact_kind_same_agency_fk
        FOREIGN KEY (contact_point_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, agency_id, contact_kind);
    SQL
  end

  def create_email_addresses
    create_table :party_email_addresses, id: false, primary_key: :contact_point_id do |table|
      table.uuid :contact_point_id, null: false, primary_key: true
      table.uuid :agency_id, null: false
      table.string :contact_kind, null: false, default: "email"
      table.string :display_address, null: false
      table.string :normalized_address, null: false
      table.string :email_type, null: false
      table.integer :normalization_version, null: false, default: 1
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :party_email_addresses,
      [ :contact_point_id, :agency_id ],
      unique: true,
      name: "index_party_email_addresses_on_contact_point_and_agency"
    add_check_constraint :party_email_addresses,
      "contact_kind = 'email'",
      name: "party_email_addresses_contact_kind_email"
    add_check_constraint :party_email_addresses,
      "btrim(display_address) <> ''",
      name: "party_email_addresses_display_address_not_blank"
    add_check_constraint :party_email_addresses,
      "btrim(normalized_address) <> ''",
      name: "party_email_addresses_normalized_address_not_blank"
    add_check_constraint :party_email_addresses,
      "email_type IN ('personal', 'work', 'general', 'booking', 'accounting', 'other')",
      name: "party_email_addresses_email_type_valid"
    add_check_constraint :party_email_addresses,
      "lock_version >= 0",
      name: "party_email_addresses_lock_version_nonnegative"
    add_foreign_key :party_email_addresses, :agencies

    execute <<~SQL
      ALTER TABLE party_email_addresses
        ADD CONSTRAINT party_email_addresses_contact_kind_same_agency_fk
        FOREIGN KEY (contact_point_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, agency_id, contact_kind);
    SQL
  end

  def create_purpose_assignments
    create_table :contact_point_purpose_assignments,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :party_id, null: false
      table.uuid :contact_point_id, null: false
      table.string :contact_kind, null: false
      table.string :purpose, null: false
      table.integer :priority, null: false
      table.date :effective_from
      table.date :effective_until
      table.string :record_status, null: false, default: "valid"
      table.uuid :superseded_by_assignment_id
      table.timestamptz :corrected_at
      table.uuid :corrected_by_membership_id
      table.string :correction_reason
      table.timestamptz :ended_at
      table.uuid :ended_by_membership_id
      table.string :ending_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :contact_point_purpose_assignments,
      [ :contact_point_id, :agency_id ],
      name: "index_contact_point_purpose_assignments_on_contact_point"
    add_check_constraint :contact_point_purpose_assignments,
      "purpose IN ('general', 'correspondence', 'billing')",
      name: "contact_point_purpose_assignments_purpose_valid"
    add_check_constraint :contact_point_purpose_assignments,
      "priority >= 1",
      name: "contact_point_purpose_assignments_priority_positive"
    add_check_constraint :contact_point_purpose_assignments,
      "record_status IN ('valid', 'superseded', 'voided')",
      name: "contact_point_purpose_assignments_record_status_valid"
    add_check_constraint :contact_point_purpose_assignments,
      "effective_until IS NULL OR effective_from IS NULL OR effective_until > effective_from",
      name: "contact_point_purpose_assignments_range_order"
    add_check_constraint :contact_point_purpose_assignments,
      "lock_version >= 0",
      name: "contact_point_purpose_assignments_lock_version_nonnegative"
    add_check_constraint :contact_point_purpose_assignments,
      <<~SQL.squish,
        (record_status = 'valid'
          AND superseded_by_assignment_id IS NULL
          AND corrected_at IS NULL
          AND corrected_by_membership_id IS NULL
          AND correction_reason IS NULL)
        OR
        (record_status = 'superseded'
          AND superseded_by_assignment_id IS NOT NULL
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
        OR
        (record_status = 'voided'
          AND corrected_at IS NOT NULL
          AND corrected_by_membership_id IS NOT NULL
          AND btrim(correction_reason) <> '')
      SQL
      name: "cppa_disposition_matches_status"
    add_check_constraint :contact_point_purpose_assignments,
      <<~SQL.squish,
        (ended_at IS NULL
          AND ended_by_membership_id IS NULL
          AND ending_reason IS NULL)
        OR
        (ended_at IS NOT NULL
          AND ended_by_membership_id IS NOT NULL
          AND btrim(ending_reason) <> ''
          AND effective_until IS NOT NULL)
      SQL
      name: "cppa_ending_complete"

    execute <<~SQL
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_contact_kind_same_agency_fk
        FOREIGN KEY (contact_point_id, agency_id, contact_kind)
        REFERENCES party_contact_points (id, agency_id, contact_kind);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_corrected_by_membership_fk
        FOREIGN KEY (corrected_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_ended_by_membership_fk
        FOREIGN KEY (ended_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_superseded_by_fk
        FOREIGN KEY (superseded_by_assignment_id)
        REFERENCES contact_point_purpose_assignments (id);
    SQL

    execute <<~SQL
      ALTER TABLE contact_point_purpose_assignments
        ADD CONSTRAINT cppa_unique_valid_primary
        EXCLUDE USING gist (
          agency_id WITH =,
          party_id WITH =,
          contact_kind WITH =,
          purpose WITH =,
          daterange(effective_from, effective_until, '[)') WITH &&
        )
        WHERE (record_status = 'valid' AND priority = 1);
    SQL
  end
end
