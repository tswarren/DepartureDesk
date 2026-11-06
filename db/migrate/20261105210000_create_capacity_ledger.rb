# frozen_string_literal: true

# Slice 1 step 3a (INV-05, INV-10, INV-26, ADR 0018 and its spike amendment,
# D-88): unit shells and the capacity ledger, recreated without version
# provenance. Events key to the inventory group; pool groups also name their
# pool and shell-level events name their shell. Allocations come in step 6.
class CreateCapacityLedger < ActiveRecord::Migration[8.1]
  EVENT_TYPES = %w[established increased released reinstated withdrawn corrected_up corrected_down].freeze

  def up
    create_table :unit_shells, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :inventory_group_id, null: false
      table.string :label, null: false
      table.integer :positions, null: false
      table.string :supplier_assignment
      table.integer :position, null: false
      table.timestamps

      table.index %i[inventory_group_id label], unique: true, name: "index_unit_shells_on_group_and_label"
      table.index %i[id agency_id], unique: true, name: "index_unit_shells_on_id_and_agency_id"
      table.index %i[id inventory_group_id], unique: true, name: "index_unit_shells_on_id_and_group"
      table.check_constraint "btrim(label) <> '' AND char_length(label) <= 40", name: "unit_shells_label"
      table.check_constraint "positions >= 1 AND position >= 1", name: "unit_shells_counts"
      table.check_constraint "supplier_assignment IS NULL OR (btrim(supplier_assignment) <> '' AND char_length(supplier_assignment) <= 40)", name: "unit_shells_assignment"
    end

    create_table :capacity_pools, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :inventory_group_id, null: false
      table.string :availability_promise, null: false
      table.timestamps

      table.index :inventory_group_id, unique: true, name: "index_capacity_pools_on_group"
      table.index %i[id inventory_group_id], unique: true, name: "index_capacity_pools_on_id_and_group"
      table.check_constraint <<~SQL.squish, name: "capacity_pools_availability_promise"
        availability_promise IN ('firm_block', 'releasable_block', 'courtesy_option', 'on_request', 'rate_only')
      SQL
    end

    create_table :capacity_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :inventory_group_id, null: false
      table.uuid :capacity_pool_id
      table.uuid :unit_shell_id
      table.string :event_type, null: false
      table.bigint :quantity, null: false
      table.date :effective_on, null: false
      table.string :effective_time_zone, null: false
      table.datetime :applies_at, null: false
      table.integer :effective_sequence, null: false
      table.datetime :recorded_at, null: false
      table.text :evidence_note
      table.uuid :corrects_event_id
      table.uuid :actor_id, null: false
      table.string :idempotency_key, null: false
      table.datetime :created_at, null: false

      table.index %i[agency_id idempotency_key], unique: true, name: "index_capacity_events_on_agency_and_idempotency_key"
      table.index %i[inventory_group_id effective_on effective_sequence], name: "index_capacity_events_on_group_timeline"
      table.index :unit_shell_id, where: "unit_shell_id IS NOT NULL", name: "index_capacity_events_on_unit_shell"
      table.check_constraint "event_type IN (#{EVENT_TYPES.map { |type| quote(type) }.join(", ")})", name: "capacity_events_type"
      table.check_constraint "quantity > 0", name: "capacity_events_quantity_positive"
      table.check_constraint "effective_sequence > 0", name: "capacity_events_sequence_positive"
      table.check_constraint "btrim(effective_time_zone) <> ''", name: "capacity_events_effective_time_zone"
      table.check_constraint "(event_type IN ('corrected_up', 'corrected_down')) = (corrects_event_id IS NOT NULL)", name: "capacity_events_correction_pair"
      table.check_constraint "event_type = 'established' OR (evidence_note IS NOT NULL AND btrim(evidence_note) <> '' AND char_length(evidence_note) <= 500)", name: "capacity_events_evidence"
      table.check_constraint "unit_shell_id IS NULL OR quantity = 1", name: "capacity_events_shell_quantity"
    end

    create_table :capacity_projections, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :inventory_group_id, null: false
      table.bigint :current_supplier_capacity, null: false, default: 0
      table.uuid :last_event_id
      table.date :last_effective_on
      table.integer :last_effective_sequence
      table.datetime :last_recorded_at
      table.uuid :next_event_id
      table.datetime :next_applies_at
      table.datetime :rebuilt_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :inventory_group_id, unique: true, name: "index_capacity_projections_on_group"
      table.check_constraint "current_supplier_capacity >= 0", name: "capacity_projections_current_nonnegative"
      table.check_constraint "lock_version >= 0", name: "capacity_projections_lock_version"
    end

    execute <<~SQL
      ALTER TABLE unit_shells
        ADD CONSTRAINT fk_unit_shells_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_unit_shells_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id);
      ALTER TABLE capacity_pools
        ADD CONSTRAINT fk_capacity_pools_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_capacity_pools_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id);
      ALTER TABLE capacity_events
        ADD CONSTRAINT fk_capacity_events_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_capacity_events_arrangement_same_departure FOREIGN KEY (supplier_arrangement_id, departure_id) REFERENCES supplier_arrangements (id, departure_id),
        ADD CONSTRAINT fk_capacity_events_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id),
        ADD CONSTRAINT fk_capacity_events_pool_of_group FOREIGN KEY (capacity_pool_id, inventory_group_id) REFERENCES capacity_pools (id, inventory_group_id),
        ADD CONSTRAINT fk_capacity_events_shell_of_group FOREIGN KEY (unit_shell_id, inventory_group_id) REFERENCES unit_shells (id, inventory_group_id),
        ADD CONSTRAINT fk_capacity_events_corrects FOREIGN KEY (corrects_event_id) REFERENCES capacity_events (id),
        ADD CONSTRAINT fk_capacity_events_actor_same_agency FOREIGN KEY (actor_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE capacity_projections
        ADD CONSTRAINT fk_capacity_projections_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_capacity_projections_group_same_agency FOREIGN KEY (inventory_group_id, agency_id) REFERENCES inventory_groups (id, agency_id),
        ADD CONSTRAINT fk_capacity_projections_last_event FOREIGN KEY (last_event_id) REFERENCES capacity_events (id),
        ADD CONSTRAINT fk_capacity_projections_next_event FOREIGN KEY (next_event_id) REFERENCES capacity_events (id);

      -- Carried over from the shipped ledger (ADR 0018 spike amendment).
      CREATE FUNCTION public.reject_capacity_event_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'capacity events are append-only';
      END;
      $$;
      CREATE TRIGGER capacity_events_reject_mutation BEFORE DELETE OR UPDATE ON public.capacity_events
        FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_event_mutation();

      -- INV-04: On request and Rate only groups, and no shared inventory, hold no numeric record.
      CREATE FUNCTION public.reject_nonnumeric_capacity_record() RETURNS trigger
          LANGUAGE plpgsql AS $$
      DECLARE
        grp record;
      BEGIN
        SELECT representation, availability_promise INTO grp FROM inventory_groups WHERE id = NEW.inventory_group_id;
        IF grp.representation = 'none' OR grp.availability_promise IN ('on_request', 'rate_only') THEN
          RAISE EXCEPTION 'inventory group % holds no numeric capacity', NEW.inventory_group_id;
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER capacity_events_reject_nonnumeric BEFORE INSERT ON public.capacity_events
        FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_record();
      CREATE TRIGGER capacity_projections_reject_nonnumeric BEFORE INSERT ON public.capacity_projections
        FOR EACH ROW EXECUTE FUNCTION public.reject_nonnumeric_capacity_record();

      CREATE FUNCTION public.reject_capacity_owner_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.agency_id IS DISTINCT FROM OLD.agency_id OR NEW.inventory_group_id IS DISTINCT FROM OLD.inventory_group_id THEN
          RAISE EXCEPTION 'capacity record ownership is immutable';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER unit_shells_reject_owner_change BEFORE UPDATE ON public.unit_shells
        FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();
      CREATE TRIGGER capacity_pools_reject_owner_change BEFORE UPDATE ON public.capacity_pools
        FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();
      CREATE TRIGGER capacity_projections_reject_owner_change BEFORE UPDATE ON public.capacity_projections
        FOR EACH ROW EXECUTE FUNCTION public.reject_capacity_owner_change();

      CREATE FUNCTION public.reject_invalid_capacity_event_zone() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM now() AT TIME ZONE NEW.effective_time_zone;
        RETURN NEW;
      EXCEPTION WHEN invalid_parameter_value THEN
        RAISE EXCEPTION 'capacity event zone % is not a recognized time zone', NEW.effective_time_zone;
      END;
      $$;
      CREATE TRIGGER capacity_events_reject_invalid_zone BEFORE INSERT ON public.capacity_events
        FOR EACH ROW EXECUTE FUNCTION public.reject_invalid_capacity_event_zone();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
