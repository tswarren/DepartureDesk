# frozen_string_literal: true

# Slice 1 step 7 (INV-33 to INV-37, SUP-10, REF-09; step 7 plan questions 1,
# 2 and 5): supplier reservations, the booking units each covers, and their
# append-only dated events.
class CreateBookingSupplierReservations < ActiveRecord::Migration[8.1]
  def up
    create_table :supplier_reservations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :client_booking_id, null: false
      table.string :status, null: false, default: "requested"
      table.string :supplier_reference
      table.date :responded_on
      table.text :response_note
      table.uuid :requested_by_id, null: false
      table.datetime :requested_at, null: false
      table.uuid :responded_by_id
      table.datetime :responded_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[id agency_id], unique: true, name: "index_supplier_reservations_on_id_and_agency_id"
      table.index %i[supplier_arrangement_id requested_at], name: "index_supplier_reservations_on_arrangement"
      table.index %i[client_booking_id requested_at], name: "index_supplier_reservations_on_booking"
      table.check_constraint "status IN ('requested', 'confirmed', 'declined', 'cancelled')", name: "supplier_reservations_status"
      table.check_constraint "supplier_reference IS NULL OR (btrim(supplier_reference) <> '' AND char_length(supplier_reference) <= 120)", name: "supplier_reservations_reference"
      table.check_constraint "response_note IS NULL OR (btrim(response_note) <> '' AND char_length(response_note) <= 2000)", name: "supplier_reservations_note"
      # INV-35: an accepted reservation carries the supplier's reference and the date of its answer.
      table.check_constraint <<~SQL.squish, name: "supplier_reservations_response"
        COALESCE(
          (status = 'requested' AND responded_on IS NULL AND responded_by_id IS NULL AND responded_at IS NULL)
          OR (status = 'confirmed' AND supplier_reference IS NOT NULL AND responded_on IS NOT NULL AND responded_by_id IS NOT NULL AND responded_at IS NOT NULL)
          OR status IN ('declined', 'cancelled'), false)
      SQL
      table.check_constraint "lock_version >= 0", name: "supplier_reservations_lock_version"
    end

    create_table :supplier_reservation_units, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_reservation_id, null: false
      table.uuid :choice_selection_id, null: false
      # Question 2: a unit is covered by one Requested or Confirmed reservation at a time.
      table.boolean :open, null: false, default: true
      table.datetime :created_at, null: false

      table.index %i[id agency_id], unique: true, name: "index_supplier_reservation_units_on_id_and_agency_id"
      table.index %i[supplier_reservation_id choice_selection_id], unique: true, name: "index_supplier_reservation_units_once_per_reservation"
      table.index :choice_selection_id, unique: true, where: "open", name: "index_supplier_reservation_units_one_open_per_selection"
    end

    create_table :supplier_reservation_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_reservation_id, null: false
      table.string :event_type, null: false
      table.date :occurred_on, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index %i[supplier_reservation_id recorded_at], name: "index_supplier_reservation_events_on_reservation"
      table.check_constraint "event_type IN ('requested', 'confirmed', 'declined', 'cancelled')", name: "supplier_reservation_events_type"
    end

    execute <<~SQL
      ALTER TABLE supplier_reservations
        ADD CONSTRAINT fk_supplier_reservations_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_reservations_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_supplier_reservations_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_supplier_reservations_requester_same_agency FOREIGN KEY (requested_by_id, agency_id) REFERENCES agency_users (id, agency_id),
        ADD CONSTRAINT fk_supplier_reservations_responder_same_agency FOREIGN KEY (responded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE supplier_reservation_units
        ADD CONSTRAINT fk_supplier_reservation_units_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_reservation_units_reservation_same_agency FOREIGN KEY (supplier_reservation_id, agency_id) REFERENCES supplier_reservations (id, agency_id),
        ADD CONSTRAINT fk_supplier_reservation_units_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id);
      ALTER TABLE supplier_reservation_events
        ADD CONSTRAINT fk_supplier_reservation_events_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_reservation_events_reservation_same_agency FOREIGN KEY (supplier_reservation_id, agency_id) REFERENCES supplier_reservations (id, agency_id),
        ADD CONSTRAINT fk_supplier_reservation_events_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      -- INV-26: a supplier request and its answer are dated events, never edited or removed.
      CREATE FUNCTION public.reject_supplier_reservation_event_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'supplier_reservation_events rows are append-only';
      END;
      $$;
      CREATE TRIGGER supplier_reservation_events_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_reservation_events
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_reservation_event_mutation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
