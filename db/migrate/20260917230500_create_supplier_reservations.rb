class CreateSupplierReservations < ActiveRecord::Migration[8.1]
  def up
    create_supplier_reservations
    create_supplier_reservation_revisions
    create_supplier_reservation_scopes
    create_supplier_reservation_events
    create_supplier_reservation_event_scope_outcomes
    create_supplier_reservation_projections
    create_reservation_triggers
  end

  def down
    drop_table :supplier_reservation_projections
    drop_table :supplier_reservation_event_scope_outcomes
    drop_table :supplier_reservation_events
    drop_table :supplier_reservation_scopes
    drop_table :supplier_reservation_revisions
    drop_table :supplier_reservations
    execute <<~SQL
      DROP FUNCTION IF EXISTS reject_supplier_reservation_owner_change();
    SQL
  end

  private

  def create_supplier_reservations
    create_table :supplier_reservations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :booking_supplier_id, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_reservation_identity_indexes
    add_arrangement_fk(:supplier_reservations)
    add_supplier_fk(:supplier_reservations, :booking_supplier_id, "supplier_reservations_booking_supplier_fk")
    add_check_constraint :supplier_reservations, "lock_version >= 0",
      name: "supplier_reservations_lock_version"
  end

  def create_supplier_reservation_revisions
    create_table :supplier_reservation_revisions, id: :uuid, default: -> { "uuidv7()" } do |table|
      reservation_owner_columns(table)
      table.uuid :supplier_arrangement_version_id, null: false
      table.integer :revision_number, null: false
      table.string :status, null: false
      table.uuid :actor_id, null: false
      table.timestamptz :requested_at
      table.timestamptz :abandoned_at
      table.string :abandoned_reason, limit: 500
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_revision_indexes
    add_reservation_fk(:supplier_reservation_revisions)
    add_version_fk(:supplier_reservation_revisions)
    add_actor_fk(:supplier_reservation_revisions)
    add_check_constraint :supplier_reservation_revisions,
      "status IN ('planned', 'requested', 'superseded', 'abandoned')",
      name: "reservation_revisions_status"
    add_check_constraint :supplier_reservation_revisions,
      "revision_number > 0", name: "reservation_revisions_number_positive"
    add_check_constraint :supplier_reservation_revisions,
      "lock_version >= 0", name: "reservation_revisions_lock_version"
    add_check_constraint :supplier_reservation_revisions,
      "(status = 'planned' AND requested_at IS NULL AND abandoned_at IS NULL AND abandoned_reason IS NULL) OR " \
      "(status = 'requested' AND requested_at IS NOT NULL AND abandoned_at IS NULL AND abandoned_reason IS NULL) OR " \
      "(status = 'superseded' AND requested_at IS NOT NULL AND abandoned_at IS NULL AND abandoned_reason IS NULL) OR " \
      "(status = 'abandoned' AND requested_at IS NULL AND abandoned_at IS NOT NULL AND abandoned_reason IS NOT NULL)",
      name: "reservation_revisions_lifecycle_shape"
    text_check(:supplier_reservation_revisions, :abandoned_reason, 500)
  end

  def create_supplier_reservation_scopes
    create_table :supplier_reservation_scopes, id: :uuid, default: -> { "uuidv7()" } do |table|
      revision_owner_columns(table)
      table.integer :position, null: false
      table.string :target_kind, null: false
      table.uuid :arrangement_item_id
      table.uuid :service_occurrence_id
      table.uuid :supplier_resource_id
      table.uuid :capacity_pool_id
      table.string :label, limit: 160
      table.bigint :requested_quantity
      table.string :quantity_basis
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_scope_indexes
    add_revision_fk(:supplier_reservation_scopes)
    add_optional_exact_structure_fks(:supplier_reservation_scopes)
    add_check_constraint :supplier_reservation_scopes,
      "target_kind IN ('arrangement', 'item', 'occurrence', 'resource', 'capacity_pool')",
      name: "reservation_scopes_target_kind"
    add_check_constraint :supplier_reservation_scopes,
      "(target_kind = 'arrangement' AND arrangement_item_id IS NULL AND service_occurrence_id IS NULL AND supplier_resource_id IS NULL AND capacity_pool_id IS NULL) OR " \
      "(target_kind = 'item' AND arrangement_item_id IS NOT NULL AND service_occurrence_id IS NULL AND supplier_resource_id IS NULL AND capacity_pool_id IS NULL) OR " \
      "(target_kind = 'occurrence' AND arrangement_item_id IS NOT NULL AND service_occurrence_id IS NOT NULL AND supplier_resource_id IS NULL AND capacity_pool_id IS NULL) OR " \
      "(target_kind = 'resource' AND arrangement_item_id IS NOT NULL AND service_occurrence_id IS NULL AND supplier_resource_id IS NOT NULL AND capacity_pool_id IS NULL) OR " \
      "(target_kind = 'capacity_pool' AND arrangement_item_id IS NOT NULL AND service_occurrence_id IS NOT NULL AND supplier_resource_id IS NOT NULL AND capacity_pool_id IS NOT NULL)",
      name: "reservation_scopes_target_shape"
    add_check_constraint :supplier_reservation_scopes,
      "(requested_quantity IS NULL AND quantity_basis IS NULL) OR " \
      "(requested_quantity > 0 AND quantity_basis IN ('resource_units', 'traveler_positions'))",
      name: "reservation_scopes_quantity_shape"
    add_check_constraint :supplier_reservation_scopes, "position > 0",
      name: "reservation_scopes_position_positive"
    add_check_constraint :supplier_reservation_scopes, "lock_version >= 0",
      name: "reservation_scopes_lock_version"
    text_check(:supplier_reservation_scopes, :label, 160)
  end

  def create_supplier_reservation_events
    create_table :supplier_reservation_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      revision_owner_columns(table)
      table.string :event_kind, null: false
      table.timestamptz :occurred_at, null: false
      table.timestamptz :recorded_at, null: false
      table.uuid :actor_id, null: false
      table.uuid :supplier_contact_id
      table.string :channel, limit: 80
      table.string :safe_contact_snapshot, limit: 500
      table.string :reference_note, limit: 500
      table.string :reason, limit: 500
      table.string :scope_fingerprint, limit: 128
      table.uuid :agency_command_idempotency_key_id
      table.timestamps null: false
    end
    add_event_indexes
    add_revision_fk(:supplier_reservation_events)
    add_actor_fk(:supplier_reservation_events)
    add_contact_fk(:supplier_reservation_events)
    add_foreign_key :supplier_reservation_events, :agency_command_idempotency_keys,
      column: [ :agency_command_idempotency_key_id, :agency_id ],
      primary_key: [ :id, :agency_id ], name: "reservation_events_idempotency_fk"
    add_check_constraint :supplier_reservation_events,
      "event_kind IN ('request', 'withdrawal', 'cancellation', 'response', 'revision')",
      name: "reservation_events_kind"
    add_check_constraint :supplier_reservation_events,
      "(event_kind IN ('request', 'response') AND channel IS NOT NULL AND reference_note IS NOT NULL) OR " \
      "(event_kind IN ('withdrawal', 'cancellation') AND reason IS NOT NULL) OR " \
      "(event_kind = 'revision')",
      name: "reservation_events_required_context"
    text_check(:supplier_reservation_events, :channel, 80)
    text_check(:supplier_reservation_events, :safe_contact_snapshot, 500)
    text_check(:supplier_reservation_events, :reference_note, 500)
    text_check(:supplier_reservation_events, :reason, 500)
    text_check(:supplier_reservation_events, :scope_fingerprint, 128)
  end

  def create_supplier_reservation_event_scope_outcomes
    create_table :supplier_reservation_event_scope_outcomes, id: :uuid, default: -> { "uuidv7()" } do |table|
      revision_owner_columns(table)
      table.uuid :supplier_reservation_event_id, null: false
      table.uuid :supplier_reservation_scope_id, null: false
      table.string :outcome_kind, null: false
      table.bigint :quantity
      table.string :quantity_basis
      table.string :supplier_note, limit: 500
      table.string :decline_reason, limit: 500
      table.timestamps null: false
    end
    add_outcome_indexes
    add_event_fk(:supplier_reservation_event_scope_outcomes)
    add_scope_fk(:supplier_reservation_event_scope_outcomes)
    add_check_constraint :supplier_reservation_event_scope_outcomes,
      "outcome_kind IN ('requested', 'withdrawn', 'cancelled', 'confirmed', 'declined', 'counterproposed')",
      name: "reservation_outcomes_kind"
    add_check_constraint :supplier_reservation_event_scope_outcomes,
      "(quantity IS NULL AND quantity_basis IS NULL) OR " \
      "(quantity > 0 AND quantity_basis IN ('resource_units', 'traveler_positions'))",
      name: "reservation_outcomes_quantity_shape"
    add_check_constraint :supplier_reservation_event_scope_outcomes,
      "(outcome_kind = 'declined') = (decline_reason IS NOT NULL)",
      name: "reservation_outcomes_decline_reason"
    text_check(:supplier_reservation_event_scope_outcomes, :supplier_note, 500)
    text_check(:supplier_reservation_event_scope_outcomes, :decline_reason, 500,
      name: "reservation_outcomes_decline_reason_text")
  end

  def create_supplier_reservation_projections
    create_table :supplier_reservation_projections, id: :uuid, default: -> { "uuidv7()" } do |table|
      reservation_owner_columns(table)
      table.uuid :current_revision_id
      table.string :state, null: false
      table.integer :planned_scope_count, null: false, default: 0
      table.integer :pending_scope_count, null: false, default: 0
      table.integer :confirmed_scope_count, null: false, default: 0
      table.integer :counterproposed_scope_count, null: false, default: 0
      table.integer :declined_scope_count, null: false, default: 0
      table.integer :withdrawn_scope_count, null: false, default: 0
      table.integer :cancelled_scope_count, null: false, default: 0
      table.timestamptz :rebuilt_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps null: false
    end
    add_projection_indexes
    add_reservation_fk(:supplier_reservation_projections)
    add_foreign_key :supplier_reservation_projections, :supplier_reservation_revisions,
      column: [ :current_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "reservation_projections_current_revision_fk"
    add_check_constraint :supplier_reservation_projections,
      "state IN ('planned', 'requested', 'partially_confirmed', 'confirmed', 'declined', 'withdrawn', 'cancelled')",
      name: "reservation_projections_state"
    add_check_constraint :supplier_reservation_projections,
      "planned_scope_count >= 0 AND pending_scope_count >= 0 AND confirmed_scope_count >= 0 AND " \
      "counterproposed_scope_count >= 0 AND declined_scope_count >= 0 AND withdrawn_scope_count >= 0 AND " \
      "cancelled_scope_count >= 0",
      name: "reservation_projections_counts_nonnegative"
    add_check_constraint :supplier_reservation_projections, "lock_version >= 0",
      name: "reservation_projections_lock_version"
  end

  def add_reservation_identity_indexes
    add_index :supplier_reservations, [ :id, :agency_id ], unique: true,
      name: "index_supplier_reservations_on_id_agency"
    add_index :supplier_reservations, [ :id, :departure_id, :agency_id ], unique: true,
      name: "index_supplier_reservations_on_id_departure_agency"
    add_index :supplier_reservations, [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_supplier_reservations_on_full_owner"
    add_index :supplier_reservations, [ :agency_id, :supplier_arrangement_id, :booking_supplier_id, :id ],
      name: "index_supplier_reservations_on_arrangement_supplier"
  end

  def add_revision_indexes
    add_index :supplier_reservation_revisions,
      [ :id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_reservation_revisions_on_owner"
    add_index :supplier_reservation_revisions,
      [ :supplier_reservation_id, :revision_number ],
      unique: true, name: "index_reservation_revisions_on_number"
    add_index :supplier_reservation_revisions, [ :supplier_reservation_id, :status ],
      unique: true, where: "status = 'planned'",
      name: "index_reservation_revisions_on_one_planned"
  end

  def add_scope_indexes
    add_index :supplier_reservation_scopes,
      [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_reservation_scopes_on_owner"
    add_index :supplier_reservation_scopes,
      [ :supplier_reservation_revision_id, :position ],
      unique: true, name: "index_reservation_scopes_on_position"
    add_index :supplier_reservation_scopes,
      [ :supplier_reservation_revision_id, :target_kind, :arrangement_item_id, :service_occurrence_id, :supplier_resource_id, :capacity_pool_id ],
      unique: true, name: "index_reservation_scopes_on_target"
  end

  def add_event_indexes
    add_index :supplier_reservation_events,
      [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_reservation_events_on_owner"
    add_index :supplier_reservation_events,
      [ :supplier_reservation_id, :recorded_at, :id ],
      name: "index_reservation_events_on_timeline"
    add_index :supplier_reservation_events,
      [ :agency_command_idempotency_key_id, :agency_id ],
      unique: true, where: "agency_command_idempotency_key_id IS NOT NULL",
      name: "index_reservation_events_on_idempotency"
  end

  def add_outcome_indexes
    add_index :supplier_reservation_event_scope_outcomes,
      [ :supplier_reservation_event_id, :supplier_reservation_scope_id ],
      unique: true, name: "index_reservation_outcomes_on_event_scope"
    add_index :supplier_reservation_event_scope_outcomes,
      [ :supplier_reservation_id, :supplier_reservation_scope_id, :created_at, :id ],
      name: "index_reservation_outcomes_on_scope_timeline"
  end

  def add_projection_indexes
    add_index :supplier_reservation_projections, :supplier_reservation_id,
      unique: true, name: "index_reservation_projections_on_reservation"
    add_index :supplier_reservation_projections,
      [ :agency_id, :supplier_arrangement_id, :state, :supplier_reservation_id ],
      name: "index_reservation_projections_on_arrangement_state"
  end

  def create_reservation_triggers
    execute <<~SQL
      CREATE FUNCTION reject_supplier_reservation_owner_change() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id <> OLD.agency_id OR
           NEW.departure_id <> OLD.departure_id OR
           NEW.supplier_arrangement_id <> OLD.supplier_arrangement_id OR
           NEW.booking_supplier_id <> OLD.booking_supplier_id THEN
          RAISE EXCEPTION 'supplier_reservations owner columns are immutable';
        END IF;
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER supplier_reservations_reject_owner_change
      BEFORE UPDATE ON supplier_reservations
      FOR EACH ROW EXECUTE FUNCTION reject_supplier_reservation_owner_change();

      CREATE TRIGGER supplier_reservation_events_reject_update
      BEFORE UPDATE ON supplier_reservation_events
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      CREATE TRIGGER supplier_reservation_events_reject_delete
      BEFORE DELETE ON supplier_reservation_events
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();

      CREATE TRIGGER supplier_reservation_outcomes_reject_update
      BEFORE UPDATE ON supplier_reservation_event_scope_outcomes
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
      CREATE TRIGGER supplier_reservation_outcomes_reject_delete
      BEFORE DELETE ON supplier_reservation_event_scope_outcomes
      FOR EACH ROW EXECUTE FUNCTION reject_m3d_immutable_mutation();
    SQL
  end

  def reservation_owner_columns(table)
    table.references :agency, null: false, type: :uuid, foreign_key: true
    table.uuid :departure_id, null: false
    table.uuid :supplier_arrangement_id, null: false
    table.uuid :supplier_reservation_id, null: false
  end

  def revision_owner_columns(table)
    reservation_owner_columns(table)
    table.uuid :supplier_arrangement_version_id, null: false
    table.uuid :supplier_reservation_revision_id, null: false
  end

  def add_arrangement_fk(table)
    add_foreign_key table, :supplier_arrangements,
      column: [ :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_arrangement_fk"
  end

  def add_reservation_fk(table)
    add_foreign_key table, :supplier_reservations,
      column: [ :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_reservation_fk"
  end

  def add_version_fk(table)
    add_foreign_key table, :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_version_fk"
  end

  def add_revision_fk(table)
    add_foreign_key table, :supplier_reservation_revisions,
      column: [ :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_revision_fk"
  end

  def add_event_fk(table)
    add_foreign_key table, :supplier_reservation_events,
      column: [ :supplier_reservation_event_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_event_fk"
  end

  def add_scope_fk(table)
    add_foreign_key table, :supplier_reservation_scopes,
      column: [ :supplier_reservation_scope_id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_reservation_revision_id, :supplier_reservation_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_scope_fk"
  end

  def add_optional_exact_structure_fks(table)
    add_foreign_key table, :arrangement_item_definitions,
      column: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_item_definition_fk"
    add_foreign_key table, :service_occurrence_definitions,
      column: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :service_occurrence_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_occurrence_definition_fk"
    add_foreign_key table, :supplier_resource_definitions,
      column: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_resource_definition_fk"
    add_foreign_key table, :capacity_pools,
      column: [ :capacity_pool_id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_occurrence_id, :supplier_resource_id, :arrangement_item_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "#{prefix(table)}_capacity_pool_fk"
  end

  def add_supplier_fk(table, column, name)
    add_foreign_key table, :suppliers,
      column: [ column, :agency_id ], primary_key: [ :id, :agency_id ], name: name
  end

  def add_actor_fk(table)
    add_foreign_key table, :agency_users,
      column: [ :actor_id, :agency_id ], primary_key: [ :id, :agency_id ],
      name: "#{prefix(table)}_actor_fk"
  end

  def add_contact_fk(table)
    add_foreign_key table, :supplier_contacts,
      column: [ :supplier_contact_id, :agency_id ],
      primary_key: [ :id, :agency_id ],
      name: "#{prefix(table)}_contact_fk"
  end

  def text_check(table, column, limit, name: nil)
    add_check_constraint table,
      "#{column} IS NULL OR (btrim(#{column}) <> '' AND char_length(#{column}) <= #{limit})",
      name: name || "#{prefix(table)}_#{column}"
  end

  def prefix(table)
    {
      supplier_reservation_revisions: "reservation_revisions",
      supplier_reservation_scopes: "reservation_scopes",
      supplier_reservation_events: "reservation_events",
      supplier_reservation_event_scope_outcomes: "reservation_outcomes",
      supplier_reservation_projections: "reservation_projections"
    }.fetch(table.to_sym, table.to_s)
  end
end
