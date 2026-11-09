# frozen_string_literal: true

# Slice 1 step 8b (SMN-04, SMN-06, SMN-17 to SMN-19, SMN-22, SMN-23,
# SMN-32, SMN-33, D-96, D-97; step 8 plan questions 9 to 13): supplier
# payments with their applications and reversals, the arrangement balance
# basis for schedule lines, and confirming an expected commission.
class CreateSupplierPayments < ActiveRecord::Migration[8.1]
  def up
    create_table :supplier_payments, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_id, null: false
      table.uuid :payee_account_id
      table.string :payment_reference, null: false
      table.date :paid_on, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :payment_method, null: false
      table.string :bank_reference
      table.string :invoice_reference
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index %i[id agency_id], unique: true, name: "index_supplier_payments_on_id_and_agency_id"
      table.index %i[agency_id payment_reference], unique: true, name: "index_supplier_payments_on_agency_and_reference"
      table.index %i[departure_id supplier_id paid_on], name: "index_supplier_payments_on_departure_and_supplier"
      table.check_constraint "payment_reference ~ '^SPY-[0-9]{4,}$'", name: "supplier_payments_reference_format"
      table.check_constraint "amount_minor_units > 0 AND currency ~ '^[A-Z]{3}$'", name: "supplier_payments_amount"
      table.check_constraint "payment_method IN ('bank_transfer', 'card', 'check', 'cash', 'other')", name: "supplier_payments_method"
      table.check_constraint "bank_reference IS NULL OR (btrim(bank_reference) <> '' AND char_length(bank_reference) <= 120)", name: "supplier_payments_bank_reference"
      table.check_constraint "invoice_reference IS NULL OR (btrim(invoice_reference) <> '' AND char_length(invoice_reference) <= 120)", name: "supplier_payments_invoice_reference"
    end

    create_table :supplier_payment_applications, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_payment_id, null: false
      table.uuid :amount_due_id, null: false
      # SMN-23: a reversal adds negative applications; nothing is edited.
      table.bigint :amount_minor_units, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :created_at, null: false

      table.index :supplier_payment_id, name: "index_supplier_payment_applications_on_payment"
      table.index :amount_due_id, name: "index_supplier_payment_applications_on_amount_due"
      table.check_constraint "amount_minor_units <> 0", name: "supplier_payment_applications_amount"
    end

    create_table :supplier_payment_reversals, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_payment_id, null: false
      table.string :reason, null: false
      table.date :reversed_on, null: false
      table.uuid :recorded_by_id, null: false
      table.datetime :recorded_at, null: false

      table.index :supplier_payment_id, unique: true, name: "index_supplier_payment_reversals_one_per_payment"
      table.check_constraint "btrim(reason) <> '' AND char_length(reason) <= 500", name: "supplier_payment_reversals_reason"
    end

    # SMN-33, D-96 (4): Expected, then Confirmed with the supplier's amount.
    add_column :expected_commissions, :confirmed_by_id, :uuid
    add_column :expected_commissions, :confirmed_at, :datetime

    execute <<~SQL
      ALTER TABLE supplier_payments
        ADD CONSTRAINT fk_supplier_payments_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_payments_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_supplier_payments_supplier_same_agency FOREIGN KEY (supplier_id, agency_id) REFERENCES suppliers (id, agency_id),
        ADD CONSTRAINT fk_supplier_payments_payee_same_agency FOREIGN KEY (payee_account_id, agency_id) REFERENCES payee_accounts (id, agency_id),
        ADD CONSTRAINT fk_supplier_payments_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE supplier_payment_applications
        ADD CONSTRAINT fk_supplier_payment_applications_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_payment_applications_payment_same_agency FOREIGN KEY (supplier_payment_id, agency_id) REFERENCES supplier_payments (id, agency_id),
        ADD CONSTRAINT fk_supplier_payment_applications_amount_same_agency FOREIGN KEY (amount_due_id, agency_id) REFERENCES amounts_due (id, agency_id),
        ADD CONSTRAINT fk_supplier_payment_applications_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE supplier_payment_reversals
        ADD CONSTRAINT fk_supplier_payment_reversals_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_payment_reversals_payment_same_agency FOREIGN KEY (supplier_payment_id, agency_id) REFERENCES supplier_payments (id, agency_id),
        ADD CONSTRAINT fk_supplier_payment_reversals_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE expected_commissions
        ADD CONSTRAINT fk_expected_commissions_confirmer_same_agency FOREIGN KEY (confirmed_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      ALTER TABLE expected_commissions DROP CONSTRAINT expected_commissions_status;
      ALTER TABLE expected_commissions ADD CONSTRAINT expected_commissions_status CHECK (
        COALESCE((status = 'expected' AND confirmed_by_id IS NULL AND confirmed_at IS NULL)
          OR (status = 'confirmed' AND confirmed_by_id IS NOT NULL AND confirmed_at IS NOT NULL), false));

      -- D-96 (2): the arrangement's balance, calculated when it posts.
      ALTER TABLE schedule_lines DROP CONSTRAINT schedule_lines_amount_kind;
      ALTER TABLE schedule_lines ADD CONSTRAINT schedule_lines_amount_kind CHECK (COALESCE(
        (amount_kind = 'fixed' AND amount_minor_units >= 0 AND rate_minor_units IS NULL AND percentage IS NULL)
        OR (amount_kind = 'percentage_of_cost_line' AND cost_line_id IS NOT NULL AND percentage > 0 AND percentage <= 100 AND amount_minor_units IS NULL AND rate_minor_units IS NULL)
        OR (amount_kind IN ('per_unit_count', 'per_shell') AND rate_minor_units >= 0 AND amount_minor_units IS NULL AND percentage IS NULL)
        OR (amount_kind = 'balance' AND amount_minor_units IS NULL AND rate_minor_units IS NULL AND percentage IS NULL AND cost_line_id IS NULL), false));

      -- SMN-18, SMN-23: supplier payments, applications and reversals are never edited or removed.
      CREATE TRIGGER supplier_payments_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payments
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER supplier_payment_applications_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payment_applications
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
      CREATE TRIGGER supplier_payment_reversals_reject_mutation BEFORE DELETE OR UPDATE ON public.supplier_payment_reversals
        FOR EACH ROW EXECUTE FUNCTION public.reject_client_money_mutation();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
