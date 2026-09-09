class CreatePhase3bSupplierPlanningFoundation < ActiveRecord::Migration[8.1]
  def up
    add_index :departures, [ :id, :agency_id, :office_id ], unique: true, name: "index_departures_on_id_agency_id_office_id"
    create_supplier_arrangements
    create_supplier_reservations
    create_supplier_resources
    create_supplier_reservation_resources
    create_supplier_service_occurrences
    create_supplier_confirmations
    create_arrangement_cycle_guard
  end

  def down
    execute "DROP TRIGGER IF EXISTS supplier_arrangements_cycle_guard ON supplier_arrangements"
    execute "DROP FUNCTION IF EXISTS supplier_arrangements_prevent_cycle()"
    drop_table :supplier_confirmations
    drop_table :supplier_service_occurrences
    drop_table :supplier_reservation_resources
    drop_table :supplier_resources
    drop_table :supplier_reservations
    drop_table :supplier_arrangements
    remove_index :departures, name: "index_departures_on_id_agency_id_office_id"
  end

  private

  def create_supplier_arrangements
    create_table :supplier_arrangements, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :parent_arrangement_id
      table.uuid :supplier_party_id, null: false
      table.uuid :service_provider_party_id
      table.string :name, null: false
      table.text :description
      table.text :client_facing_description
      table.string :status, null: false, default: "draft"
      table.string :supplier_display_name_snapshot, null: false
      table.string :service_provider_display_name_snapshot
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_arrangements, [ :id, :agency_id ], unique: true, name: "index_sa_on_id_and_agency_id"
    add_index :supplier_arrangements, [ :id, :agency_id, :office_id, :departure_id ], unique: true, name: "index_sa_on_id_agency_office_departure"
    add_index :supplier_arrangements, [ :departure_id, :agency_id, :office_id ], name: "index_sa_on_departure_agency_office"
    add_index :supplier_arrangements, [ :parent_arrangement_id, :agency_id ], name: "index_sa_on_parent_and_agency"
    add_index :supplier_arrangements, [ :supplier_party_id, :agency_id ], name: "index_sa_on_supplier_party_and_agency"
    add_index :supplier_arrangements, [ :service_provider_party_id, :agency_id ], name: "index_sa_on_provider_party_and_agency"

    add_check_constraint :supplier_arrangements, "status IN ('draft', 'active', 'cancelled')", name: "supplier_arrangements_status_valid"
    add_check_constraint :supplier_arrangements, "lock_version >= 0", name: "supplier_arrangements_lock_version_nonnegative"
    add_check_constraint :supplier_arrangements, "btrim(name) <> ''", name: "supplier_arrangements_name_not_blank"
    add_check_constraint :supplier_arrangements, "parent_arrangement_id IS NULL OR parent_arrangement_id <> id", name: "supplier_arrangements_no_self_parent"
    add_check_constraint :supplier_arrangements,
      <<~SQL.squish,
        (status IN ('draft', 'active') AND status_reason IS NULL)
        OR (status = 'cancelled' AND btrim(status_reason) <> '')
      SQL
      name: "supplier_arrangements_status_metadata"
    add_check_constraint :supplier_arrangements,
      "service_provider_party_id IS NULL OR service_provider_display_name_snapshot IS NOT NULL",
      name: "supplier_arrangements_provider_snapshot"

    execute <<~SQL
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_office_same_agency_fk
        FOREIGN KEY (office_id, agency_id)
        REFERENCES offices (id, agency_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_parent_same_scope_fk
        FOREIGN KEY (parent_arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_supplier_party_fk
        FOREIGN KEY (supplier_party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_provider_party_fk
        FOREIGN KEY (service_provider_party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_arrangements
        ADD CONSTRAINT supplier_arrangements_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_reservations
    create_table :supplier_reservations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.string :name, null: false
      table.string :status, null: false, default: "requested"
      table.text :operational_notes
      table.string :confirmed_without_identifier_reason
      table.timestamptz :confirmed_without_identifier_at
      table.uuid :confirmed_without_identifier_by_membership_id
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_reservations, [ :id, :agency_id ], unique: true, name: "index_sr_on_id_and_agency_id"
    add_index :supplier_reservations, [ :id, :agency_id, :office_id, :departure_id ], unique: true, name: "index_sr_on_id_agency_office_departure"
    add_index :supplier_reservations, [ :id, :agency_id, :office_id, :departure_id, :arrangement_id ], unique: true, name: "index_sr_on_id_agency_office_departure_arrangement"
    add_index :supplier_reservations, [ :arrangement_id, :agency_id ], name: "index_sr_on_arrangement_and_agency"
    add_index :supplier_reservations, [ :departure_id, :agency_id, :office_id ], name: "index_sr_on_departure_agency_office"

    add_check_constraint :supplier_reservations,
      "status IN ('requested', 'submitted', 'confirmed', 'declined', 'unable_to_confirm', 'cancelled')",
      name: "supplier_reservations_status_valid"
    add_check_constraint :supplier_reservations, "lock_version >= 0", name: "supplier_reservations_lock_version_nonnegative"
    add_check_constraint :supplier_reservations, "btrim(name) <> ''", name: "supplier_reservations_name_not_blank"
    add_check_constraint :supplier_reservations,
      <<~SQL.squish,
        (status = 'confirmed' AND (
          (confirmed_without_identifier_reason IS NULL AND confirmed_without_identifier_at IS NULL AND confirmed_without_identifier_by_membership_id IS NULL)
          OR
          (btrim(confirmed_without_identifier_reason) <> '' AND confirmed_without_identifier_at IS NOT NULL AND confirmed_without_identifier_by_membership_id IS NOT NULL)
        ))
        OR
        (status <> 'confirmed' AND confirmed_without_identifier_reason IS NULL AND confirmed_without_identifier_at IS NULL AND confirmed_without_identifier_by_membership_id IS NULL)
      SQL
      name: "supplier_reservations_confirmation_metadata"
    add_check_constraint :supplier_reservations,
      <<~SQL.squish,
        (status IN ('cancelled', 'declined', 'unable_to_confirm') AND btrim(status_reason) <> '')
        OR (status IN ('requested', 'submitted', 'confirmed') AND status_reason IS NULL)
      SQL
      name: "supplier_reservations_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT supplier_reservations_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT supplier_reservations_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT supplier_reservations_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT supplier_reservations_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT supplier_reservations_confirmed_by_membership_fk
        FOREIGN KEY (confirmed_without_identifier_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_resources
    create_table :supplier_resources, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.string :name, null: false
      table.string :resource_kind, null: false
      table.string :capacity_unit, null: false
      table.text :description
      table.string :status, null: false, default: "active"
      table.uuid :created_by_membership_id, null: false
      table.timestamptz :status_changed_at, null: false
      table.uuid :status_changed_by_membership_id, null: false
      table.string :status_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_resources, [ :id, :agency_id ], unique: true, name: "index_sres_on_id_and_agency_id"
    add_index :supplier_resources, [ :id, :agency_id, :office_id, :departure_id ], unique: true, name: "index_sres_on_id_agency_office_departure"
    add_index :supplier_resources, [ :id, :agency_id, :office_id, :departure_id, :arrangement_id ], unique: true, name: "index_sres_on_id_agency_office_departure_arrangement"
    add_index :supplier_resources, [ :arrangement_id, :agency_id ], name: "index_sres_on_arrangement_and_agency"

    add_check_constraint :supplier_resources, "status IN ('active', 'inactive')", name: "supplier_resources_status_valid"
    add_check_constraint :supplier_resources, "lock_version >= 0", name: "supplier_resources_lock_version_nonnegative"
    add_check_constraint :supplier_resources, "btrim(name) <> ''", name: "supplier_resources_name_not_blank"
    add_check_constraint :supplier_resources, "btrim(resource_kind) <> ''", name: "supplier_resources_kind_not_blank"
    add_check_constraint :supplier_resources, "capacity_unit IN ('seat', 'room', 'cabin', 'vehicle', 'policy', 'unit')", name: "supplier_resources_capacity_unit_valid"
    add_check_constraint :supplier_resources,
      <<~SQL.squish,
        (status = 'active' AND status_reason IS NULL)
        OR (status = 'inactive' AND btrim(status_reason) <> '')
      SQL
      name: "supplier_resources_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_resources
        ADD CONSTRAINT supplier_resources_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_resources
        ADD CONSTRAINT supplier_resources_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_resources
        ADD CONSTRAINT supplier_resources_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_resources
        ADD CONSTRAINT supplier_resources_status_by_membership_fk
        FOREIGN KEY (status_changed_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_reservation_resources
    create_table :supplier_reservation_resources, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :reservation_id, null: false
      table.uuid :resource_id, null: false
      table.uuid :created_by_membership_id, null: false
      table.timestamps null: false
    end

    add_index :supplier_reservation_resources, [ :reservation_id, :resource_id ], unique: true, name: "index_srr_on_reservation_and_resource"
    add_index :supplier_reservation_resources, [ :resource_id, :agency_id ], name: "index_srr_on_resource_and_agency"

    execute <<~SQL
      ALTER TABLE supplier_reservation_resources
        ADD CONSTRAINT srr_reservation_scope_fk
        FOREIGN KEY (reservation_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_reservations (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_reservation_resources
        ADD CONSTRAINT srr_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_reservation_resources
        ADD CONSTRAINT srr_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_service_occurrences
    create_table :supplier_service_occurrences, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :resource_id, null: false
      table.string :occurrence_kind, null: false
      table.date :service_date
      table.string :segment_type
      table.string :segment_identifier
      table.string :label
      table.uuid :created_by_membership_id, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_service_occurrences, [ :id, :agency_id ], unique: true, name: "index_sso_on_id_and_agency_id"
    add_index :supplier_service_occurrences, [ :resource_id, :agency_id ], name: "index_sso_on_resource_and_agency"
    add_index :supplier_service_occurrences,
      [ :resource_id, :occurrence_kind, :service_date ],
      unique: true,
      where: "occurrence_kind = 'night_slice'",
      name: "index_sso_unique_night_slice"
    add_index :supplier_service_occurrences,
      [ :resource_id, :occurrence_kind, :segment_type, :segment_identifier ],
      unique: true,
      where: "occurrence_kind = 'typed_segment'",
      name: "index_sso_unique_typed_segment"

    add_check_constraint :supplier_service_occurrences, "occurrence_kind IN ('night_slice', 'typed_segment')", name: "supplier_occurrences_kind_valid"
    add_check_constraint :supplier_service_occurrences, "lock_version >= 0", name: "supplier_occurrences_lock_version_nonnegative"
    add_check_constraint :supplier_service_occurrences,
      <<~SQL.squish,
        (occurrence_kind = 'night_slice' AND service_date IS NOT NULL AND segment_type IS NULL AND segment_identifier IS NULL)
        OR
        (occurrence_kind = 'typed_segment' AND service_date IS NULL AND btrim(segment_type) <> '' AND btrim(segment_identifier) <> '')
      SQL
      name: "supplier_occurrences_kind_identity"

    execute <<~SQL
      ALTER TABLE supplier_service_occurrences
        ADD CONSTRAINT sso_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_service_occurrences
        ADD CONSTRAINT sso_created_by_membership_fk
        FOREIGN KEY (created_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_supplier_confirmations
    create_table :supplier_confirmations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id
      table.uuid :reservation_id
      table.uuid :issuer_party_id, null: false
      table.string :issuer_display_name_snapshot, null: false
      table.string :identifier_type, null: false
      table.string :context, null: false
      table.string :raw_value, null: false
      table.string :normalized_value, null: false
      table.date :issued_on
      table.date :received_on
      table.string :source_channel
      table.string :document_reference
      table.string :status, null: false, default: "effective"
      table.uuid :entered_by_membership_id, null: false
      table.timestamptz :superseded_at
      table.uuid :superseded_by_membership_id
      table.string :supersession_reason
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_confirmations, [ :id, :agency_id ], unique: true, name: "index_sc_on_id_and_agency_id"
    add_index :supplier_confirmations, [ :arrangement_id, :agency_id ], name: "index_sc_on_arrangement_and_agency"
    add_index :supplier_confirmations, [ :reservation_id, :agency_id ], name: "index_sc_on_reservation_and_agency"
    add_index :supplier_confirmations,
      [ :agency_id, :issuer_party_id, :identifier_type, :context, :normalized_value ],
      unique: true,
      name: "index_sc_unique_issuer_context_value"

    add_check_constraint :supplier_confirmations, "status IN ('effective', 'superseded')", name: "supplier_confirmations_status_valid"
    add_check_constraint :supplier_confirmations, "lock_version >= 0", name: "supplier_confirmations_lock_version_nonnegative"
    add_check_constraint :supplier_confirmations, "(arrangement_id IS NULL) <> (reservation_id IS NULL)", name: "supplier_confirmations_exactly_one_owner"
    add_check_constraint :supplier_confirmations, "btrim(identifier_type) <> ''", name: "supplier_confirmations_type_not_blank"
    add_check_constraint :supplier_confirmations, "btrim(context) <> ''", name: "supplier_confirmations_context_not_blank"
    add_check_constraint :supplier_confirmations, "btrim(raw_value) <> ''", name: "supplier_confirmations_raw_value_not_blank"
    add_check_constraint :supplier_confirmations, "btrim(normalized_value) <> ''", name: "supplier_confirmations_normalized_value_not_blank"
    add_check_constraint :supplier_confirmations,
      <<~SQL.squish,
        (status = 'effective' AND superseded_at IS NULL AND superseded_by_membership_id IS NULL AND supersession_reason IS NULL)
        OR (status = 'superseded' AND superseded_at IS NOT NULL AND superseded_by_membership_id IS NOT NULL AND btrim(supersession_reason) <> '')
      SQL
      name: "supplier_confirmations_status_metadata"

    execute <<~SQL
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_reservation_scope_fk
        FOREIGN KEY (reservation_id, agency_id, office_id, departure_id)
        REFERENCES supplier_reservations (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_issuer_party_fk
        FOREIGN KEY (issuer_party_id, agency_id)
        REFERENCES parties (id, agency_id);
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_entered_by_membership_fk
        FOREIGN KEY (entered_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_confirmations
        ADD CONSTRAINT supplier_confirmations_superseded_by_membership_fk
        FOREIGN KEY (superseded_by_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
    SQL
  end

  def create_arrangement_cycle_guard
    execute <<~SQL
      CREATE FUNCTION supplier_arrangements_prevent_cycle()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.parent_arrangement_id IS NULL THEN
          RETURN NEW;
        END IF;

        IF NEW.parent_arrangement_id = NEW.id THEN
          RAISE EXCEPTION 'supplier arrangement cannot parent itself' USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
          WITH RECURSIVE ancestors(id, parent_arrangement_id) AS (
            SELECT id, parent_arrangement_id
            FROM supplier_arrangements
            WHERE id = NEW.parent_arrangement_id
              AND agency_id = NEW.agency_id
              AND office_id = NEW.office_id
              AND departure_id = NEW.departure_id
            UNION ALL
            SELECT parent.id, parent.parent_arrangement_id
            FROM supplier_arrangements parent
            JOIN ancestors child ON child.parent_arrangement_id = parent.id
            WHERE parent.agency_id = NEW.agency_id
              AND parent.office_id = NEW.office_id
              AND parent.departure_id = NEW.departure_id
          )
          SELECT 1 FROM ancestors WHERE id = NEW.id LIMIT 1
        ) THEN
          RAISE EXCEPTION 'supplier arrangement hierarchy cannot contain cycles' USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE CONSTRAINT TRIGGER supplier_arrangements_cycle_guard
      AFTER INSERT OR UPDATE OF parent_arrangement_id ON supplier_arrangements
      DEFERRABLE INITIALLY IMMEDIATE
      FOR EACH ROW
      EXECUTE FUNCTION supplier_arrangements_prevent_cycle();
    SQL
  end
end
