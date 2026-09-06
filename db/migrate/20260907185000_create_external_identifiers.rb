class CreateExternalIdentifiers < ActiveRecord::Migration[8.1]
  def up
    create_table :external_identifiers,
      id: :uuid,
      default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :party_id
      table.uuid :client_profile_id
      table.uuid :supplier_profile_id
      table.uuid :office_id
      table.string :identifier_type, null: false
      table.string :issuer
      table.string :original_value, null: false
      table.string :normalized_value, null: false
      table.integer :normalization_version, null: false
      table.string :status, null: false
      table.string :source, null: false
      table.timestamptz :deactivated_at
      table.uuid :deactivated_by_membership_id
      table.string :deactivation_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :external_identifiers, [ :id, :agency_id ], unique: true, name: "index_external_identifiers_on_id_and_agency_id"
    add_index :external_identifiers, [ :party_id, :agency_id ], name: "index_external_identifiers_on_party"
    add_index :external_identifiers, [ :client_profile_id, :agency_id ], name: "index_external_identifiers_on_client_profile"
    add_index :external_identifiers, [ :supplier_profile_id, :agency_id ], name: "index_external_identifiers_on_supplier_profile"

    add_check_constraint :external_identifiers,
      "lock_version >= 0",
      name: "external_identifiers_lock_version_nonnegative"
    add_check_constraint :external_identifiers,
      "status IN ('active', 'inactive')",
      name: "external_identifiers_status_valid"
    add_check_constraint :external_identifiers,
      "source IN ('staff')",
      name: "external_identifiers_source_valid"
    add_check_constraint :external_identifiers,
      "btrim(original_value) <> '' AND btrim(normalized_value) <> ''",
      name: "external_identifiers_values_not_blank"
    add_check_constraint :external_identifiers,
      "office_id IS NULL",
      name: "external_identifiers_office_id_null"
    add_check_constraint :external_identifiers,
      <<~SQL.squish,
        ((party_id IS NOT NULL)::int + (client_profile_id IS NOT NULL)::int + (supplier_profile_id IS NOT NULL)::int) = 1
      SQL
      name: "external_identifiers_exactly_one_owner"
    add_check_constraint :external_identifiers,
      <<~SQL.squish,
        (identifier_type = 'legacy_party_id' AND party_id IS NOT NULL AND client_profile_id IS NULL AND supplier_profile_id IS NULL)
        OR (identifier_type IN ('legacy_client_id', 'external_crm_id') AND client_profile_id IS NOT NULL AND party_id IS NULL AND supplier_profile_id IS NULL)
        OR (identifier_type IN ('supplier_account_number', 'supplier_portal_id', 'industry_supplier_code') AND supplier_profile_id IS NOT NULL AND party_id IS NULL AND client_profile_id IS NULL)
      SQL
      name: "external_identifiers_type_owner"
    add_check_constraint :external_identifiers,
      <<~SQL.squish,
        identifier_type NOT IN ('legacy_client_id', 'external_crm_id', 'supplier_account_number', 'supplier_portal_id', 'industry_supplier_code')
        OR (issuer IS NOT NULL AND btrim(issuer) <> '')
      SQL
      name: "external_identifiers_issuer_required"
    add_check_constraint :external_identifiers,
      <<~SQL.squish,
        (status = 'active' AND deactivated_at IS NULL AND deactivated_by_membership_id IS NULL AND deactivation_reason IS NULL)
        OR (status = 'inactive' AND deactivated_at IS NOT NULL AND deactivated_by_membership_id IS NOT NULL AND btrim(deactivation_reason) <> '')
      SQL
      name: "external_identifiers_lifecycle"

    add_index :external_identifiers,
      [ :agency_id, :issuer, :normalized_value ],
      unique: true,
      where: "status = 'active' AND identifier_type = 'legacy_client_id'",
      name: "index_external_identifiers_unique_legacy_client_id"
    add_index :external_identifiers,
      [ :agency_id, :issuer, :normalized_value ],
      unique: true,
      where: "status = 'active' AND identifier_type = 'external_crm_id'",
      name: "index_external_identifiers_unique_external_crm_id"
    add_index :external_identifiers,
      [ :agency_id, :issuer, :normalized_value ],
      unique: true,
      where: "status = 'active' AND identifier_type = 'supplier_account_number'",
      name: "index_external_identifiers_unique_supplier_account_number"
    add_index :external_identifiers,
      [ :agency_id, :issuer, :normalized_value ],
      unique: true,
      where: "status = 'active' AND identifier_type = 'supplier_portal_id'",
      name: "index_external_identifiers_unique_supplier_portal_id"
    add_index :external_identifiers,
      [ :agency_id, :issuer, :normalized_value ],
      unique: true,
      where: "status = 'active' AND identifier_type = 'industry_supplier_code'",
      name: "index_external_identifiers_unique_industry_supplier_code"

    execute <<~SQL
      ALTER TABLE external_identifiers
        ADD CONSTRAINT external_identifiers_party_same_agency_fk
        FOREIGN KEY (party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE external_identifiers
        ADD CONSTRAINT external_identifiers_client_profile_same_agency_fk
        FOREIGN KEY (client_profile_id, agency_id)
        REFERENCES client_profiles (id, agency_id);
      ALTER TABLE external_identifiers
        ADD CONSTRAINT external_identifiers_supplier_profile_same_agency_fk
        FOREIGN KEY (supplier_profile_id, agency_id)
        REFERENCES supplier_profiles (id, agency_id);
      ALTER TABLE external_identifiers
        ADD CONSTRAINT external_identifiers_deactivated_by_membership_fk
        FOREIGN KEY (deactivated_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL

    execute <<~SQL
      CREATE FUNCTION external_identifiers_prevent_identity_change() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.party_id IS DISTINCT FROM OLD.party_id
          OR NEW.client_profile_id IS DISTINCT FROM OLD.client_profile_id
          OR NEW.supplier_profile_id IS DISTINCT FROM OLD.supplier_profile_id
          OR NEW.identifier_type IS DISTINCT FROM OLD.identifier_type
          OR NEW.issuer IS DISTINCT FROM OLD.issuer
          OR NEW.original_value IS DISTINCT FROM OLD.original_value
          OR NEW.normalization_version IS DISTINCT FROM OLD.normalization_version THEN
          RAISE EXCEPTION 'external identifier identity cannot change';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER external_identifiers_identity_immutable
        BEFORE UPDATE ON external_identifiers
        FOR EACH ROW
        EXECUTE FUNCTION external_identifiers_prevent_identity_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS external_identifiers_identity_immutable ON external_identifiers;
      DROP FUNCTION IF EXISTS external_identifiers_prevent_identity_change();
    SQL
    drop_table :external_identifiers
  end
end
