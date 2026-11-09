# frozen_string_literal: true

# Slice 1 step 8a (CMN-06, CMN-08, CMN-09, CMN-12, CMN-18, CMN-19, CMN-21,
# CMN-23, CMN-24, CMN-27 to CMN-29, CMN-55, BKG-41, D-94, D-96; step 8 plan
# questions 1 to 8): installment proposals on a draft booking, installments
# on a charge, client payments by route with their applications and
# reversals, receipts, and the designated-payment acceptance link.
class CreateClientMoney < ActiveRecord::Migration[8.1]
  def up
    # Question 1: what the current proposals were proposed from, so an adjustment survives unrelated edits.
    add_column :client_bookings, :installment_basis, :string

    create_table :installment_proposals, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_booking_id, null: false
      table.integer :position, null: false
      table.string :description, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :due_kind, null: false
      table.date :due_on
      table.boolean :adjusted, null: false, default: false
      table.timestamps

      table.index %i[client_booking_id position], unique: true, name: "index_installment_proposals_on_booking_and_position"
      table.check_constraint "position >= 1", name: "installment_proposals_position"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 120", name: "installment_proposals_description"
      table.check_constraint "amount_minor_units >= 0 AND currency ~ '^[A-Z]{3}$'", name: "installment_proposals_amount"
      table.check_constraint "COALESCE((due_kind = 'at_confirmation' AND due_on IS NULL) OR (due_kind = 'on_date' AND due_on IS NOT NULL), false)", name: "installment_proposals_due"
    end

    create_table :installments, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_charge_id, null: false
      table.integer :position, null: false
      table.string :description, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.date :due_on, null: false
      table.string :route, null: false, default: "agency"
      table.datetime :created_at, null: false

      table.index %i[id agency_id], unique: true, name: "index_installments_on_id_and_agency_id"
      table.index %i[client_charge_id position], unique: true, name: "index_installments_on_charge_and_position"
      table.check_constraint "position >= 1", name: "installments_position"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 300", name: "installments_description"
      table.check_constraint "amount_minor_units >= 0 AND currency ~ '^[A-Z]{3}$'", name: "installments_amount"
      table.check_constraint "route IN ('agency', 'supplier')", name: "installments_route"
    end

    create_table :client_payments, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_trip_id, null: false
      table.string :payment_reference, null: false
      table.uuid :payer_client_id, null: false
      table.date :paid_on, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :route, null: false
      table.uuid :supplier_id
      table.string :payment_method, null: false
      table.string :reference
      table.string :supplier_reference
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index %i[id agency_id], unique: true, name: "index_client_payments_on_id_and_agency_id"
      table.index %i[agency_id payment_reference], unique: true, name: "index_client_payments_on_agency_and_reference"
      table.index %i[client_trip_id paid_on], name: "index_client_payments_on_trip"
      table.check_constraint "payment_reference ~ '^PAY-[0-9]{5,}$'", name: "client_payments_reference_format"
      table.check_constraint "amount_minor_units > 0 AND currency ~ '^[A-Z]{3}$'", name: "client_payments_amount"
      # CMN-29: the route says whether money reached the agency or a named supplier.
      table.check_constraint "COALESCE((route = 'agency' AND supplier_id IS NULL) OR (route = 'supplier' AND supplier_id IS NOT NULL), false)", name: "client_payments_route"
      table.check_constraint "payment_method IN ('check', 'bank_transfer', 'card', 'cash', 'other')", name: "client_payments_method"
      table.check_constraint "reference IS NULL OR (btrim(reference) <> '' AND char_length(reference) <= 120)", name: "client_payments_reference"
      table.check_constraint "supplier_reference IS NULL OR (btrim(supplier_reference) <> '' AND char_length(supplier_reference) <= 120)", name: "client_payments_supplier_reference"
    end

    create_table :client_payment_applications, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_payment_id, null: false
      table.uuid :installment_id, null: false
      # CMN-27: a reversal adds negative applications; nothing is edited.
      table.bigint :amount_minor_units, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :created_at, null: false

      table.index :client_payment_id, name: "index_client_payment_applications_on_payment"
      table.index :installment_id, name: "index_client_payment_applications_on_installment"
      table.check_constraint "amount_minor_units <> 0", name: "client_payment_applications_amount"
    end

    create_table :client_payment_reversals, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_payment_id, null: false
      table.string :reason, null: false
      table.date :reversed_on, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index :client_payment_id, unique: true, name: "index_client_payment_reversals_one_per_payment"
      table.check_constraint "btrim(reason) <> '' AND char_length(reason) <= 500", name: "client_payment_reversals_reason"
    end

    create_table :receipts, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.string :receipt_number, null: false
      table.uuid :client_payment_id, null: false
      table.uuid :departure_id, null: false
      table.string :payer_name, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.date :paid_on, null: false
      table.string :payment_method, null: false
      table.string :reference
      table.jsonb :applied, null: false, default: []
      table.datetime :issued_at, null: false

      table.index %i[agency_id receipt_number], unique: true, name: "index_receipts_on_agency_and_number"
      table.index :client_payment_id, unique: true, name: "index_receipts_one_per_payment"
      table.check_constraint "receipt_number ~ '^RCP-[0-9]{5,}$'", name: "receipts_number_format"
      table.check_constraint "amount_minor_units > 0 AND currency ~ '^[A-Z]{3}$'", name: "receipts_amount"
      table.check_constraint "jsonb_typeof(applied) = 'array'", name: "receipts_applied"
    end

    add_column :booking_acceptances, :client_payment_id, :uuid
    add_index :booking_acceptances, :client_payment_id, name: "index_booking_acceptances_on_client_payment"

    execute <<~SQL
      ALTER TABLE installment_proposals
        ADD CONSTRAINT fk_installment_proposals_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_installment_proposals_booking_same_agency FOREIGN KEY (client_booking_id, agency_id) REFERENCES client_bookings (id, agency_id);
      ALTER TABLE installments
        ADD CONSTRAINT fk_installments_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_installments_charge_same_agency FOREIGN KEY (client_charge_id, agency_id) REFERENCES client_charges (id, agency_id);
      ALTER TABLE client_payments
        ADD CONSTRAINT fk_client_payments_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_payments_trip_same_agency FOREIGN KEY (client_trip_id, agency_id) REFERENCES client_trips (id, agency_id),
        ADD CONSTRAINT fk_client_payments_payer_same_agency FOREIGN KEY (payer_client_id, agency_id) REFERENCES clients (id, agency_id),
        ADD CONSTRAINT fk_client_payments_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES suppliers (id, agency_id),
        ADD CONSTRAINT fk_client_payments_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE client_payment_applications
        ADD CONSTRAINT fk_client_payment_applications_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_payment_applications_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES client_payments (id, agency_id),
        ADD CONSTRAINT fk_client_payment_applications_installment_same_agency FOREIGN KEY (installment_id, agency_id) REFERENCES installments (id, agency_id),
        ADD CONSTRAINT fk_client_payment_applications_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE client_payment_reversals
        ADD CONSTRAINT fk_client_payment_reversals_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_payment_reversals_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES client_payments (id, agency_id),
        ADD CONSTRAINT fk_client_payment_reversals_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE receipts
        ADD CONSTRAINT fk_receipts_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_receipts_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES client_payments (id, agency_id),
        ADD CONSTRAINT fk_receipts_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id);
      ALTER TABLE booking_acceptances
        ADD CONSTRAINT fk_booking_acceptances_payment_same_agency FOREIGN KEY (client_payment_id, agency_id) REFERENCES client_payments (id, agency_id);

      -- Question 7, D-94 (3): a designated-payment acceptance links its payment; the notes exception ends.
      ALTER TABLE booking_acceptances DROP CONSTRAINT booking_acceptances_payment;
      ALTER TABLE booking_acceptances ADD CONSTRAINT booking_acceptances_payment CHECK (
        COALESCE(
          (acceptance_method = 'designated_payment' AND client_payment_id IS NOT NULL)
          OR (acceptance_method <> 'designated_payment' AND client_payment_id IS NULL), false)
        AND payment_on IS NULL AND payment_amount_minor_units IS NULL AND payment_reference IS NULL
      );

      -- CMN-03, CMN-27, CMN-55: installments, payments, applications, reversals and receipts are never edited or removed.
      CREATE FUNCTION public.reject_client_money_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION '% rows are append-only', TG_TABLE_NAME;
      END;
      $$;
      CREATE TRIGGER installments_reject_mutation BEFORE DELETE OR UPDATE ON public.installments
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER client_payments_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payments
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER client_payment_applications_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payment_applications
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER client_payment_reversals_reject_mutation BEFORE DELETE OR UPDATE ON public.client_payment_reversals
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER receipts_reject_mutation BEFORE DELETE OR UPDATE ON public.receipts
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
