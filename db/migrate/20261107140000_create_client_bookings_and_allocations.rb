# frozen_string_literal: true

# Slice 1 step 6b (BKG-05, BKG-06, BKG-09 to BKG-11, BKG-14, BKG-16, BKG-23,
# CLT-13, CLT-15, INV-07, INV-09, INV-17 to INV-21, INV-23, INV-38, INV-39,
# D-88; step 6 plan questions 14 to 21): client bookings on a Client Trip,
# their travelers, choice selections with units and occupants, inventory
# allocations, booking price lines, and the required-adult rule.
class CreateClientBookingsAndAllocations < ActiveRecord::Migration[8.1]
  def up
    # Question 21: who counts toward a unit's required adults, and the rule itself.
    add_column :traveler_types, :counts_as_adult, :boolean, null: false, default: false
    execute "UPDATE traveler_types SET counts_as_adult = true WHERE name = 'Adult'"
    add_column :inventory_groups, :required_adults_per_unit, :integer
    add_check_constraint :inventory_groups, <<~SQL.squish, name: "inventory_groups_required_adults"
      required_adults_per_unit IS NULL
      OR (required_adults_per_unit >= 1 AND (positions_per_unit IS NULL OR required_adults_per_unit <= positions_per_unit))
    SQL

    create_table :client_bookings, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_trip_id, null: false
      table.uuid :offering_id, null: false
      table.integer :sequence, null: false
      table.string :booking_reference, null: false
      table.string :status, null: false, default: "draft"
      table.string :owner_kind, null: false, default: "agency"
      table.uuid :created_by_id, null: false
      table.uuid :client_terms_version_id
      table.datetime :discarded_at
      table.datetime :confirmed_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[client_trip_id sequence], unique: true, name: "index_client_bookings_on_trip_and_sequence"
      table.index %i[agency_id booking_reference], unique: true, name: "index_client_bookings_on_agency_and_reference"
      table.index %i[id agency_id], unique: true, name: "index_client_bookings_on_id_and_agency_id"
      table.index :offering_id, name: "index_client_bookings_on_offering"
      table.check_constraint "status IN ('draft', 'confirmed', 'discarded', 'cancelled')", name: "client_bookings_status"
      # Slice 1: every booking is agency-owned; reseller ownership arrives in build step 9.
      table.check_constraint "owner_kind IN ('agency')", name: "client_bookings_owner_kind"
      table.check_constraint "sequence >= 1 AND lock_version >= 0", name: "client_bookings_counters"
      table.check_constraint "booking_reference ~ '^T-[0-9]{5,}-[0-9]+$'", name: "client_bookings_reference_format"
      table.check_constraint "(status = 'discarded') = (discarded_at IS NOT NULL)", name: "client_bookings_discarded_at"
      table.check_constraint "(status IN ('confirmed', 'cancelled')) = (confirmed_at IS NOT NULL)", name: "client_bookings_confirmed_at"
    end

    create_table :booking_travelers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :traveler_id
      table.string :placeholder_label
      table.uuid :traveler_type_id
      table.integer :position, null: false
      table.string :name_as_booked
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[client_booking_id position], name: "index_booking_travelers_on_booking_and_position"
      table.index %i[client_booking_id traveler_id], unique: true, where: "traveler_id IS NOT NULL", name: "index_booking_travelers_one_per_traveler"
      table.index :traveler_id, name: "index_booking_travelers_on_traveler"
      table.index %i[id agency_id], unique: true, name: "index_booking_travelers_on_id_and_agency_id"
      # CLT-15: a traveler or a placeholder such as "Guest 2", never both.
      table.check_constraint "num_nonnulls(traveler_id, placeholder_label) = 1", name: "booking_travelers_traveler_or_placeholder"
      table.check_constraint "placeholder_label IS NULL OR (btrim(placeholder_label) <> '' AND char_length(placeholder_label) <= 40)", name: "booking_travelers_placeholder"
      table.check_constraint "name_as_booked IS NULL OR char_length(name_as_booked) <= 300", name: "booking_travelers_name_as_booked"
      table.check_constraint "position >= 1 AND lock_version >= 0", name: "booking_travelers_counters"
    end

    create_table :choice_selections, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :offering_option_id, null: false
      table.integer :unit_number
      # A removed selection is kept while its allocation history points at it.
      table.datetime :removed_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[client_booking_id offering_option_id unit_number], unique: true, nulls_not_distinct: true, where: "removed_at IS NULL",
        name: "index_choice_selections_one_per_option_and_unit"
      table.index :offering_option_id, name: "index_choice_selections_on_option"
      table.index %i[id agency_id], unique: true, name: "index_choice_selections_on_id_and_agency_id"
      table.check_constraint "(unit_number IS NULL OR unit_number >= 1) AND lock_version >= 0", name: "choice_selections_counters"
    end

    # Question 19: a per-unit selection's occupants with their positions in
    # that unit; a per-traveler selection's participants, without positions.
    create_table :selection_occupants, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :choice_selection_id, null: false
      table.uuid :booking_traveler_id, null: false
      table.integer :position
      table.timestamps

      table.index %i[choice_selection_id booking_traveler_id], unique: true, name: "index_selection_occupants_one_per_traveler"
      table.index %i[choice_selection_id position], unique: true, where: "position IS NOT NULL", name: "index_selection_occupants_one_per_position"
      table.index :booking_traveler_id, name: "index_selection_occupants_on_traveler"
      table.check_constraint "position IS NULL OR position >= 1", name: "selection_occupants_position"
    end

    create_table :inventory_allocations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :choice_selection_id, null: false
      table.uuid :inventory_group_id, null: false
      table.uuid :unit_shell_id
      table.integer :quantity, null: false
      table.string :state, null: false, default: "held"
      table.datetime :held_at, null: false
      table.datetime :hold_expires_at
      table.datetime :hold_extended_at
      table.datetime :reserved_at
      table.datetime :released_at
      table.uuid :replaces_allocation_id
      table.uuid :created_by_id, null: false
      table.timestamps

      table.index %i[inventory_group_id state], name: "index_inventory_allocations_on_group_and_state"
      table.index %i[unit_shell_id state], name: "index_inventory_allocations_on_shell_and_state"
      table.index %i[client_booking_id state], name: "index_inventory_allocations_on_booking_and_state"
      table.index :choice_selection_id, name: "index_inventory_allocations_on_selection"
      table.index :replaces_allocation_id, name: "index_inventory_allocations_on_replaced"
      table.check_constraint "quantity >= 1", name: "inventory_allocations_quantity"
      table.check_constraint "state IN ('held', 'reserved', 'released')", name: "inventory_allocations_state"
      table.check_constraint <<~SQL.squish, name: "inventory_allocations_state_timestamps"
        (state <> 'held' OR (hold_expires_at IS NOT NULL AND reserved_at IS NULL AND released_at IS NULL))
        AND (state <> 'reserved' OR (reserved_at IS NOT NULL AND released_at IS NULL))
        AND (state <> 'released' OR released_at IS NOT NULL)
      SQL
      table.check_constraint "replaces_allocation_id IS NULL OR replaces_allocation_id <> id", name: "inventory_allocations_replaces_other"
    end

    create_table :booking_price_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :choice_selection_id, null: false
      table.uuid :booking_traveler_id
      table.uuid :offering_price_id
      table.string :occupancy_position, null: false
      table.uuid :traveler_type_id
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.timestamps

      table.index %i[choice_selection_id booking_traveler_id], unique: true, nulls_not_distinct: true, name: "index_booking_price_lines_one_per_selection_and_traveler"
      table.index :client_booking_id, name: "index_booking_price_lines_on_booking"
      table.index :offering_price_id, name: "index_booking_price_lines_on_offering_price"
      table.check_constraint "amount_minor_units >= 0", name: "booking_price_lines_amount"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "booking_price_lines_currency"
      table.check_constraint "occupancy_position IN ('any', 'single', 'guest_1', 'guest_2', 'guest_3', 'guest_4', 'guest_5', 'guest_6', 'guest_7', 'guest_8', 'guest_9')",
        name: "booking_price_lines_occupancy_position"
    end

    execute <<~SQL
      ALTER TABLE client_bookings
        ADD CONSTRAINT fk_client_bookings_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_bookings_trip_same_agency FOREIGN KEY (client_trip_id, agency_id) REFERENCES client_trips (id, agency_id),
        ADD CONSTRAINT fk_client_bookings_offering_same_agency FOREIGN KEY (offering_id, agency_id) REFERENCES offerings (id, agency_id),
        ADD CONSTRAINT fk_client_bookings_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES agency_users (id, agency_id),
        ADD CONSTRAINT fk_client_bookings_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES client_terms_versions (id, agency_id);
      ALTER TABLE booking_travelers
        ADD CONSTRAINT fk_booking_travelers_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_booking_travelers_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_booking_travelers_traveler_same_agency FOREIGN KEY (traveler_id, agency_id) REFERENCES travelers (id, agency_id),
        ADD CONSTRAINT fk_booking_travelers_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);
      ALTER TABLE choice_selections
        ADD CONSTRAINT fk_choice_selections_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_choice_selections_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_choice_selections_option_same_agency FOREIGN KEY (offering_option_id, agency_id) REFERENCES offering_options (id, agency_id);
      ALTER TABLE selection_occupants
        ADD CONSTRAINT fk_selection_occupants_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_selection_occupants_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id),
        ADD CONSTRAINT fk_selection_occupants_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES booking_travelers (id, agency_id);
      ALTER TABLE inventory_allocations
        ADD CONSTRAINT fk_inventory_allocations_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_inventory_allocations_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_inventory_allocations_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id),
        ADD CONSTRAINT fk_inventory_allocations_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id),
        ADD CONSTRAINT fk_inventory_allocations_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES unit_shells (id, agency_id),
        ADD CONSTRAINT fk_inventory_allocations_creator_same_agency FOREIGN KEY (created_by_id, agency_id) REFERENCES agency_users (id, agency_id),
        ADD CONSTRAINT fk_inventory_allocations_replaces FOREIGN KEY (replaces_allocation_id) REFERENCES inventory_allocations (id);
      ALTER TABLE booking_price_lines
        ADD CONSTRAINT fk_booking_price_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_booking_price_lines_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_booking_price_lines_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id),
        ADD CONSTRAINT fk_booking_price_lines_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES booking_travelers (id, agency_id),
        ADD CONSTRAINT fk_booking_price_lines_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id),
        -- BKG-23: removing an offering price never touches a booking's line; only the provenance link clears.
        ADD CONSTRAINT fk_booking_price_lines_offering_price FOREIGN KEY (offering_price_id) REFERENCES offering_prices (id) ON DELETE SET NULL;

      -- REF-03, REF-04: a booking's reference, trip and offering never change.
      CREATE FUNCTION public.reject_client_booking_identity_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.client_trip_id IS DISTINCT FROM OLD.client_trip_id
          OR NEW.booking_reference IS DISTINCT FROM OLD.booking_reference OR NEW.sequence IS DISTINCT FROM OLD.sequence
          OR NEW.offering_id IS DISTINCT FROM OLD.offering_id THEN
          RAISE EXCEPTION 'client booking identity is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER client_bookings_reject_identity_change BEFORE UPDATE ON public.client_bookings
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_booking_identity_change();

      -- BKG-05: a booking buys an offering of its trip's Departure.
      CREATE FUNCTION public.reject_client_booking_other_departure() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM client_trips t JOIN offerings o ON o.departure_id = t.departure_id
          WHERE t.id = NEW.client_trip_id AND o.id = NEW.offering_id
        ) THEN
          RAISE EXCEPTION 'client booking % must buy an offering of its trip''s Departure', NEW.id;
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER client_bookings_reject_other_departure BEFORE INSERT ON public.client_bookings
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_booking_other_departure();

      -- BKG-14: a selection's option belongs to its booking's offering.
      CREATE FUNCTION public.reject_choice_selection_other_offering() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM client_bookings b
            JOIN offering_choices c ON c.offering_id = b.offering_id
            JOIN offering_options o ON o.offering_choice_id = c.id
          WHERE b.id = NEW.client_booking_id AND o.id = NEW.offering_option_id
        ) THEN
          RAISE EXCEPTION 'choice selection % uses an option from another offering', NEW.id;
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER choice_selections_reject_other_offering BEFORE INSERT OR UPDATE ON public.choice_selections
        FOR EACH ROW EXECUTE FUNCTION public.reject_choice_selection_other_offering();

      -- INV-17, INV-18, D-88: an allocation draws on its selection's group (and
      -- a shell of it), and moves only forward: Held to Reserved, and Held or
      -- Reserved to Released. What it allocates never changes.
      CREATE FUNCTION public.check_inventory_allocation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'INSERT' THEN
          IF NOT EXISTS (
            SELECT 1 FROM choice_selections s JOIN offering_options o ON o.id = s.offering_option_id
            WHERE s.id = NEW.choice_selection_id AND s.client_booking_id = NEW.client_booking_id AND o.inventory_group_id = NEW.inventory_group_id
          ) THEN
            RAISE EXCEPTION 'inventory allocation % must draw on its selection''s group', NEW.id;
          END IF;
          IF NEW.unit_shell_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM unit_shells WHERE id = NEW.unit_shell_id AND inventory_group_id = NEW.inventory_group_id
          ) THEN
            RAISE EXCEPTION 'inventory allocation % names a shell of another group', NEW.id;
          END IF;
          IF NEW.state <> 'held' THEN
            RAISE EXCEPTION 'inventory allocation % must start Held', NEW.id;
          END IF;
          RETURN NEW;
        END IF;
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'inventory allocations are never deleted';
        END IF;
        IF NEW.client_booking_id IS DISTINCT FROM OLD.client_booking_id OR NEW.choice_selection_id IS DISTINCT FROM OLD.choice_selection_id
          OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id OR NEW.unit_shell_id IS DISTINCT FROM OLD.unit_shell_id
          OR NEW.quantity IS DISTINCT FROM OLD.quantity OR NEW.agency_id IS DISTINCT FROM OLD.agency_id
          OR NEW.held_at IS DISTINCT FROM OLD.held_at OR NEW.replaces_allocation_id IS DISTINCT FROM OLD.replaces_allocation_id THEN
          RAISE EXCEPTION 'inventory allocation % may change only its state', OLD.id;
        END IF;
        IF OLD.state = 'released' AND NEW IS DISTINCT FROM OLD THEN
          RAISE EXCEPTION 'released inventory allocation % never changes', OLD.id;
        END IF;
        IF OLD.state = 'reserved' AND NEW.state = 'held' THEN
          RAISE EXCEPTION 'inventory allocation % cannot return to Held', OLD.id;
        END IF;
        IF (OLD.reserved_at IS NOT NULL AND NEW.reserved_at IS DISTINCT FROM OLD.reserved_at)
          OR (OLD.hold_extended_at IS NOT NULL AND NEW.hold_extended_at IS DISTINCT FROM OLD.hold_extended_at) THEN
          RAISE EXCEPTION 'inventory allocation % timestamps are set once', OLD.id;
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER inventory_allocations_check BEFORE INSERT OR UPDATE OR DELETE ON public.inventory_allocations
        FOR EACH ROW EXECUTE FUNCTION public.check_inventory_allocation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
