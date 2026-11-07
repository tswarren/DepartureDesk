# frozen_string_literal: true

# Slice 1 step 6c (BKG-25, BKG-28, BKG-39, BKG-41, BKG-45, CMN-01 to CMN-03,
# SMN-02, SMN-11, SMN-32, SMN-33, SUP-35, D-75, D-81, D-94; step 6 plan
# questions 2, 3, 9 to 11 and 18): acceptance records, the client charge
# and its lines, booking supplier cost, expected commissions, the shells a
# Client booking confirmed event names, and tiers copied when terms lock.
class CreateAcceptanceAndConfirmationRecords < ActiveRecord::Migration[8.1]
  def up
    # Question 9: the agency tiers in effect when a version is first accepted.
    add_column :client_cancellation_tiers, :copied_from_agency_default, :boolean, null: false, default: false

    create_table :booking_acceptances, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :client_terms_version_id, null: false
      table.string :accepted_by, null: false
      table.string :acceptance_method, null: false
      table.date :accepted_on, null: false
      table.bigint :accepted_total_minor_units, null: false
      table.string :currency, null: false
      table.string :lines_fingerprint, null: false
      table.text :note
      table.string :evidence_reference
      table.string :evidence_sha256
      table.date :payment_on
      table.bigint :payment_amount_minor_units
      table.string :payment_reference
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false
      table.timestamps

      table.index %i[client_booking_id recorded_at], name: "index_booking_acceptances_on_booking_and_recorded_at"
      table.index %i[id agency_id], unique: true, name: "index_booking_acceptances_on_id_and_agency_id"
      table.check_constraint "btrim(accepted_by) <> '' AND char_length(accepted_by) <= 160", name: "booking_acceptances_accepted_by"
      table.check_constraint "acceptance_method IN ('email', 'signed', 'phone', 'in_person', 'designated_payment')", name: "booking_acceptances_method"
      table.check_constraint "accepted_total_minor_units >= 0 AND currency ~ '^[A-Z]{3}$'", name: "booking_acceptances_total"
      table.check_constraint "lines_fingerprint ~ '^[0-9a-f]{64}$'", name: "booking_acceptances_fingerprint"
      table.check_constraint "note IS NULL OR (btrim(note) <> '' AND char_length(note) <= 2000)", name: "booking_acceptances_note"
      table.check_constraint "evidence_reference IS NULL OR (btrim(evidence_reference) <> '' AND char_length(evidence_reference) <= 300)", name: "booking_acceptances_evidence_reference"
      table.check_constraint "evidence_sha256 IS NULL OR evidence_sha256 ~ '^[0-9a-f]{64}$'", name: "booking_acceptances_evidence_sha256"
      # BKG-41: email or signed keeps evidence (a file or where it is kept); phone or in person a staff note.
      table.check_constraint <<~SQL.squish, name: "booking_acceptances_evidence"
        COALESCE(
          (acceptance_method IN ('email', 'signed') AND (evidence_sha256 IS NOT NULL OR evidence_reference IS NOT NULL))
          OR (acceptance_method IN ('phone', 'in_person') AND note IS NOT NULL)
          OR acceptance_method = 'designated_payment', false)
      SQL
      # D-94 (3): until build step 8, a designated payment is noted, not linked.
      table.check_constraint <<~SQL.squish, name: "booking_acceptances_payment"
        COALESCE(
          (acceptance_method = 'designated_payment' AND payment_on IS NOT NULL AND payment_amount_minor_units > 0
            AND payment_reference IS NOT NULL AND btrim(payment_reference) <> '' AND char_length(payment_reference) <= 120)
          OR (acceptance_method <> 'designated_payment' AND payment_on IS NULL AND payment_amount_minor_units IS NULL AND payment_reference IS NULL), false)
      SQL
    end

    create_table :client_charges, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :client_terms_version_id, null: false
      table.uuid :booking_acceptance_id, null: false
      table.string :currency, null: false
      table.datetime :created_at, null: false

      table.index :client_booking_id, unique: true, name: "index_client_charges_one_per_booking"
      table.index %i[id agency_id], unique: true, name: "index_client_charges_on_id_and_agency_id"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "client_charges_currency"
    end

    create_table :charge_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_charge_id, null: false
      table.string :line_type, null: false
      table.uuid :choice_selection_id
      table.uuid :booking_traveler_id
      table.uuid :traveler_type_id
      table.string :occupancy_position
      table.string :description, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :creditor, null: false, default: "agency"
      table.string :expected_route, null: false, default: "agency"
      table.datetime :created_at, null: false

      table.index :client_charge_id, name: "index_charge_lines_on_charge"
      table.check_constraint "line_type IN ('traveler_price', 'add_on')", name: "charge_lines_type"
      table.check_constraint "creditor IN ('agency', 'supplier') AND expected_route IN ('agency', 'supplier')", name: "charge_lines_creditor_and_route"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 300", name: "charge_lines_description"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "charge_lines_currency"
    end

    create_table :expected_commissions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :client_booking_id, null: false
      table.uuid :choice_selection_id, null: false
      table.bigint :proposed_amount_minor_units, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :status, null: false, default: "expected"
      table.uuid :overridden_by_id
      table.datetime :overridden_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :choice_selection_id, unique: true, name: "index_expected_commissions_one_per_service"
      table.index :supplier_arrangement_id, name: "index_expected_commissions_on_arrangement"
      table.index :client_booking_id, name: "index_expected_commissions_on_booking"
      table.check_constraint "proposed_amount_minor_units >= 0 AND amount_minor_units >= 0 AND currency ~ '^[A-Z]{3}$'", name: "expected_commissions_amounts"
      # SMN-33: later statuses arrive with supplier money (build step 8) and reconciliation.
      table.check_constraint "status IN ('expected')", name: "expected_commissions_status"
      table.check_constraint "(overridden_by_id IS NULL) = (overridden_at IS NULL) AND lock_version >= 0", name: "expected_commissions_override"
    end

    # SMN-02, D-75: a cost line may be scoped to a client booking.
    remove_check_constraint :cost_lines, name: "cost_lines_scope"
    add_check_constraint :cost_lines, "scope IN ('arrangement', 'inventory_group', 'unit_shells', 'client_booking')", name: "cost_lines_scope"
    add_column :cost_lines, :client_booking_id, :uuid
    add_index :cost_lines, :client_booking_id, name: "index_cost_lines_on_client_booking"
    add_check_constraint :cost_lines, "(scope = 'client_booking') = (client_booking_id IS NOT NULL)", name: "cost_lines_booking_scope"

    # D-81: a Client booking confirmed event names its booking and the shells it holds.
    add_column :trigger_events, :client_booking_id, :uuid
    create_table :trigger_event_shells, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :trigger_event_id, null: false
      table.uuid :unit_shell_id, null: false
      table.datetime :created_at, null: false

      table.index %i[trigger_event_id unit_shell_id], unique: true, name: "index_trigger_event_shells_one_per_shell"
      table.index :unit_shell_id, name: "index_trigger_event_shells_on_shell"
    end

    execute <<~SQL
      ALTER TABLE booking_acceptances
        ADD CONSTRAINT fk_booking_acceptances_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_booking_acceptances_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_booking_acceptances_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES client_terms_versions (id, agency_id),
        ADD CONSTRAINT fk_booking_acceptances_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE client_charges
        ADD CONSTRAINT fk_client_charges_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_charges_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_client_charges_terms_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES client_terms_versions (id, agency_id),
        ADD CONSTRAINT fk_client_charges_acceptance_same_agency FOREIGN KEY (booking_acceptance_id, agency_id) REFERENCES booking_acceptances (id, agency_id);
      ALTER TABLE charge_lines
        ADD CONSTRAINT fk_charge_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_charge_lines_charge_same_agency FOREIGN KEY (client_charge_id, agency_id) REFERENCES client_charges (id, agency_id),
        ADD CONSTRAINT fk_charge_lines_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id),
        ADD CONSTRAINT fk_charge_lines_traveler_same_agency FOREIGN KEY (booking_traveler_id, agency_id) REFERENCES booking_travelers (id, agency_id),
        ADD CONSTRAINT fk_charge_lines_type_same_agency FOREIGN KEY (traveler_type_id, agency_id) REFERENCES traveler_types (id, agency_id);
      ALTER TABLE expected_commissions
        ADD CONSTRAINT fk_expected_commissions_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_expected_commissions_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_expected_commissions_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id),
        ADD CONSTRAINT fk_expected_commissions_selection_same_agency FOREIGN KEY (choice_selection_id, agency_id) REFERENCES choice_selections (id, agency_id),
        ADD CONSTRAINT fk_expected_commissions_overrider_same_agency FOREIGN KEY (overridden_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE cost_lines
        ADD CONSTRAINT fk_cost_lines_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id);
      ALTER TABLE trigger_events
        ADD CONSTRAINT fk_trigger_events_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id);
      ALTER TABLE trigger_event_shells
        ADD CONSTRAINT fk_trigger_event_shells_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_trigger_event_shells_event_same_agency FOREIGN KEY (trigger_event_id, agency_id) REFERENCES trigger_events (id, agency_id),
        ADD CONSTRAINT fk_trigger_event_shells_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES unit_shells (id, agency_id);

      -- BKG-41, CMN-03, SMN-11: acceptances, charges, charge lines and event shells are append-only.
      -- Active Storage touches updated_at when evidence is attached; nothing else may change.
      CREATE FUNCTION public.reject_booking_acceptance_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'booking_acceptances rows are append-only';
      END;
      $$;
      CREATE TRIGGER booking_acceptances_reject_mutation BEFORE DELETE OR UPDATE ON public.booking_acceptances
        FOR EACH ROW EXECUTE FUNCTION public.reject_booking_acceptance_mutation();
      CREATE TRIGGER client_charges_reject_mutation BEFORE DELETE OR UPDATE ON public.client_charges
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();
      CREATE TRIGGER charge_lines_reject_mutation BEFORE DELETE OR UPDATE ON public.charge_lines
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();
      CREATE TRIGGER trigger_event_shells_reject_mutation BEFORE DELETE OR UPDATE ON public.trigger_event_shells
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();

      -- BKG-25: a confirmed booking's price lines are fixed; the charge lines are the snapshot.
      CREATE FUNCTION public.reject_confirmed_booking_contents_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      DECLARE
        booking_id uuid;
      BEGIN
        booking_id := CASE WHEN TG_OP = 'INSERT' THEN NEW.client_booking_id ELSE OLD.client_booking_id END;
        IF EXISTS (SELECT 1 FROM client_bookings WHERE id = booking_id AND status <> 'draft') THEN
          RAISE EXCEPTION 'booking % is no longer a draft; its contents are fixed', booking_id;
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$;
      CREATE TRIGGER booking_price_lines_reject_confirmed_change BEFORE INSERT OR UPDATE OR DELETE ON public.booking_price_lines
        FOR EACH ROW EXECUTE FUNCTION public.reject_confirmed_booking_contents_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
