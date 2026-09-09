class CreateSupplierCapacityEventsAndPositions < ActiveRecord::Migration[8.1]
  def up
    create_supplier_capacity_positions
    create_supplier_capacity_events
    install_capacity_event_append_only_guard
  end

  def down
    remove_capacity_event_append_only_guard
    drop_table :supplier_capacity_events
    drop_table :supplier_capacity_positions
  end

  private

  def create_supplier_capacity_positions
    create_table :supplier_capacity_positions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :resource_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.string :capacity_unit, null: false
      table.integer :agency_held, null: false, default: 0
      table.integer :pending_request, null: false, default: 0
      table.integer :guaranteed, null: false, default: 0
      table.integer :consumed, null: false, default: 0
      table.integer :released_current, null: false, default: 0
      table.integer :supplier_reported_total
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end

    add_index :supplier_capacity_positions, [ :id, :agency_id ], unique: true, name: "index_scp_on_id_and_agency_id"
    add_index :supplier_capacity_positions,
      [ :resource_id, :service_occurrence_id, :capacity_unit ],
      unique: true,
      name: "index_scp_unique_resource_occurrence_unit"
    add_check_constraint :supplier_capacity_positions, "capacity_unit IN ('seat', 'room', 'cabin', 'vehicle', 'policy', 'unit')", name: "scp_capacity_unit_valid"
    add_check_constraint :supplier_capacity_positions, "agency_held >= 0", name: "scp_agency_held_nonnegative"
    add_check_constraint :supplier_capacity_positions, "pending_request >= 0", name: "scp_pending_request_nonnegative"
    add_check_constraint :supplier_capacity_positions, "guaranteed >= 0", name: "scp_guaranteed_nonnegative"
    add_check_constraint :supplier_capacity_positions, "consumed >= 0", name: "scp_consumed_nonnegative"
    add_check_constraint :supplier_capacity_positions, "released_current >= 0", name: "scp_released_current_nonnegative"
    add_check_constraint :supplier_capacity_positions, "supplier_reported_total IS NULL OR supplier_reported_total >= 0", name: "scp_supplier_total_nonnegative"
    add_check_constraint :supplier_capacity_positions, "lock_version >= 0", name: "scp_lock_version_nonnegative"
    add_check_constraint :supplier_capacity_positions, "agency_held >= consumed", name: "scp_available_nonnegative"

    execute <<~SQL
      ALTER TABLE supplier_capacity_positions
        ADD CONSTRAINT scp_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_capacity_positions
        ADD CONSTRAINT scp_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_capacity_positions
        ADD CONSTRAINT scp_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_capacity_positions
        ADD CONSTRAINT scp_occurrence_fk
        FOREIGN KEY (service_occurrence_id, agency_id)
        REFERENCES supplier_service_occurrences (id, agency_id);
    SQL
  end

  def create_supplier_capacity_events
    create_table :supplier_capacity_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :office_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :arrangement_id, null: false
      table.uuid :resource_id, null: false
      table.uuid :service_occurrence_id, null: false
      table.uuid :supplier_capacity_position_id, null: false
      table.uuid :reservation_id
      table.string :capacity_unit, null: false
      table.string :event_type, null: false
      table.integer :quantity, null: false
      table.integer :agency_held_delta, null: false, default: 0
      table.integer :pending_request_delta, null: false, default: 0
      table.integer :guaranteed_delta, null: false, default: 0
      table.integer :consumed_delta, null: false, default: 0
      table.integer :released_current_delta, null: false, default: 0
      table.timestamptz :commanded_at, null: false
      table.date :effective_on, null: false
      table.string :actor_kind, null: false
      table.uuid :actor_membership_id
      table.string :actor_identifier
      table.text :reason, null: false
      table.string :idempotency_key, null: false
      table.uuid :causation_event_id
      table.uuid :corrected_event_id
      table.string :supplier_approval_reference
      table.timestamptz :supplier_approval_received_at
      table.timestamps null: false
    end

    add_index :supplier_capacity_events, [ :id, :agency_id ], unique: true, name: "index_sce_on_id_and_agency_id"
    add_index :supplier_capacity_events, [ :agency_id, :idempotency_key ], unique: true, name: "index_sce_unique_idempotency"
    add_index :supplier_capacity_events, [ :supplier_capacity_position_id, :commanded_at, :id ], name: "index_sce_on_position_commanded"
    add_index :supplier_capacity_events, [ :resource_id, :service_occurrence_id, :capacity_unit ], name: "index_sce_on_resource_occurrence_unit"
    add_index :supplier_capacity_events, [ :reservation_id, :agency_id ], name: "index_sce_on_reservation_and_agency"

    add_check_constraint :supplier_capacity_events,
      "event_type IN ('initial_hold', 'request', 'confirm_request', 'increase', 'reduction', 'release', 'reinstatement', 'consumption', 'restoration', 'correction', 'expiration')",
      name: "sce_event_type_valid"
    add_check_constraint :supplier_capacity_events, "capacity_unit IN ('seat', 'room', 'cabin', 'vehicle', 'policy', 'unit')", name: "sce_capacity_unit_valid"
    add_check_constraint :supplier_capacity_events, "quantity > 0", name: "sce_quantity_positive"
    add_check_constraint :supplier_capacity_events, "btrim(reason) <> ''", name: "sce_reason_not_blank"
    add_check_constraint :supplier_capacity_events, "btrim(idempotency_key) <> ''", name: "sce_idempotency_key_not_blank"
    add_check_constraint :supplier_capacity_events,
      <<~SQL.squish,
        (
          actor_kind = 'membership'
          AND actor_membership_id IS NOT NULL
          AND actor_identifier IS NULL
        )
        OR
        (
          actor_kind = 'system'
          AND actor_membership_id IS NULL
          AND btrim(actor_identifier) <> ''
        )
      SQL
      name: "sce_actor_consistency"
    add_check_constraint :supplier_capacity_events,
      "(supplier_approval_reference IS NULL) = (supplier_approval_received_at IS NULL)",
      name: "sce_supplier_approval_complete"
    add_check_constraint :supplier_capacity_events,
      "(event_type <> 'consumption' AND event_type <> 'restoration') OR reservation_id IS NOT NULL",
      name: "sce_consumption_reservation_required"
    add_check_constraint :supplier_capacity_events,
      "(event_type <> 'reinstatement') OR supplier_approval_reference IS NOT NULL",
      name: "sce_reinstatement_approval_required"

    execute <<~SQL
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_departure_office_fk
        FOREIGN KEY (departure_id, agency_id, office_id)
        REFERENCES departures (id, agency_id, office_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_arrangement_scope_fk
        FOREIGN KEY (arrangement_id, agency_id, office_id, departure_id)
        REFERENCES supplier_arrangements (id, agency_id, office_id, departure_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_resource_scope_fk
        FOREIGN KEY (resource_id, agency_id, office_id, departure_id, arrangement_id)
        REFERENCES supplier_resources (id, agency_id, office_id, departure_id, arrangement_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_occurrence_fk
        FOREIGN KEY (service_occurrence_id, agency_id)
        REFERENCES supplier_service_occurrences (id, agency_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_position_fk
        FOREIGN KEY (supplier_capacity_position_id, agency_id)
        REFERENCES supplier_capacity_positions (id, agency_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_reservation_fk
        FOREIGN KEY (reservation_id, agency_id)
        REFERENCES supplier_reservations (id, agency_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_actor_membership_fk
        FOREIGN KEY (actor_membership_id, agency_id)
        REFERENCES agency_memberships (id, agency_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_causation_event_fk
        FOREIGN KEY (causation_event_id, agency_id)
        REFERENCES supplier_capacity_events (id, agency_id);
      ALTER TABLE supplier_capacity_events
        ADD CONSTRAINT sce_corrected_event_fk
        FOREIGN KEY (corrected_event_id, agency_id)
        REFERENCES supplier_capacity_events (id, agency_id);
    SQL
  end

  def install_capacity_event_append_only_guard
    execute <<~SQL
      CREATE FUNCTION prevent_supplier_capacity_event_mutation() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'supplier_capacity_events are append-only';
      END;
      $$;

      CREATE TRIGGER supplier_capacity_events_prevent_update
        BEFORE UPDATE ON supplier_capacity_events
        FOR EACH ROW
        EXECUTE FUNCTION prevent_supplier_capacity_event_mutation();

      CREATE TRIGGER supplier_capacity_events_prevent_delete
        BEFORE DELETE ON supplier_capacity_events
        FOR EACH ROW
        EXECUTE FUNCTION prevent_supplier_capacity_event_mutation();
    SQL
  end

  def remove_capacity_event_append_only_guard
    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_capacity_events_prevent_update ON supplier_capacity_events;
      DROP TRIGGER IF EXISTS supplier_capacity_events_prevent_delete ON supplier_capacity_events;
      DROP FUNCTION IF EXISTS prevent_supplier_capacity_event_mutation();
    SQL
  end
end
