# frozen_string_literal: true

# Slice 1 step 5 (BKG-28, BKG-31, BKG-41, CMN-09, D-76, D-77): the agency's
# reusable terms wording and default cancellation tiers, and each
# Departure's numbered client terms versions with their own wording, an
# optional cancellation tier override, and the payment schedule template.
class CreateClientTerms < ActiveRecord::Migration[8.1]
  CATEGORIES = %w[hotel all_inclusive_resort cruise air rail transportation activity meal insurance].freeze

  def up
    add_column :agencies, :client_terms_wording, :text
    add_check_constraint :agencies, "client_terms_wording IS NULL OR char_length(client_terms_wording) <= 20000", name: "agencies_client_terms_wording_length"

    create_table :agency_cancellation_tiers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      tier_columns(table)
      table.index %i[agency_id min_days_before_departure], unique: true, name: "index_agency_cancellation_tiers_one_per_day"
    end
    tier_checks(:agency_cancellation_tiers)

    create_table :client_terms_versions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.integer :version_number, null: false
      table.text :agency_wording
      table.text :departure_wording
      table.boolean :overrides_cancellation_tiers, null: false, default: false
      table.uuid :copied_from_departure_id
      table.datetime :locked_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[departure_id version_number], unique: true, name: "index_client_terms_versions_on_departure_and_number"
      table.index %i[id agency_id], unique: true, name: "index_client_terms_versions_on_id_and_agency_id"
      table.check_constraint "version_number >= 1 AND lock_version >= 0", name: "client_terms_versions_counters"
      table.check_constraint <<~SQL.squish, name: "client_terms_versions_wording_length"
        (agency_wording IS NULL OR char_length(agency_wording) <= 20000) AND (departure_wording IS NULL OR char_length(departure_wording) <= 20000)
      SQL
      table.check_constraint "copied_from_departure_id IS NULL OR copied_from_departure_id <> departure_id", name: "client_terms_versions_copied_from_other"
    end

    create_table :client_cancellation_tiers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_terms_version_id, null: false
      tier_columns(table)
      table.index %i[client_terms_version_id min_days_before_departure], unique: true, name: "index_client_cancellation_tiers_one_per_day"
    end
    tier_checks(:client_cancellation_tiers)

    create_table :client_payment_schedule_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :client_terms_version_id, null: false
      table.string :description, null: false
      table.string :basis, null: false
      table.string :service_category
      table.bigint :amount_minor_units
      table.decimal :percentage, precision: 7, scale: 4
      table.string :currency, null: false
      table.string :due_rule, null: false
      table.integer :days_before_departure
      table.date :due_on
      table.boolean :counts_as_acceptance, null: false, default: false
      table.integer :position, null: false, default: 0
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[client_terms_version_id position], name: "index_client_payment_schedule_lines_on_version_and_position"
      table.index :client_terms_version_id, unique: true, where: "basis = 'balance'", name: "index_client_payment_schedule_lines_one_balance"
      # BKG-41: at most one designated payment counts as acceptance.
      table.index :client_terms_version_id, unique: true, where: "counts_as_acceptance", name: "index_client_payment_schedule_lines_one_acceptance"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 120", name: "client_payment_schedule_lines_description"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "client_payment_schedule_lines_currency"
      # CMN-09, D-77: a fixed amount per traveler, per unit of a named category or per booking; a percentage; or the balance.
      table.check_constraint <<~SQL.squish, name: "client_payment_schedule_lines_basis"
        (basis IN ('per_traveler', 'per_booking') AND amount_minor_units >= 0 AND percentage IS NULL AND service_category IS NULL)
        OR (basis = 'per_unit' AND amount_minor_units >= 0 AND percentage IS NULL
            AND service_category IN (#{CATEGORIES.map { |category| quote(category) }.join(", ")}))
        OR (basis = 'percentage' AND amount_minor_units IS NULL AND percentage > 0 AND percentage <= 100 AND service_category IS NULL)
        OR (basis = 'balance' AND amount_minor_units IS NULL AND percentage IS NULL AND service_category IS NULL)
      SQL
      table.check_constraint <<~SQL.squish, name: "client_payment_schedule_lines_due_rule"
        (due_rule = 'at_confirmation' AND days_before_departure IS NULL AND due_on IS NULL)
        OR (due_rule = 'days_before_departure' AND days_before_departure >= 0 AND due_on IS NULL)
        OR (due_rule = 'fixed_date' AND days_before_departure IS NULL AND due_on IS NOT NULL)
      SQL
      table.check_constraint "position >= 0 AND lock_version >= 0", name: "client_payment_schedule_lines_counters"
    end

    execute <<~SQL
      ALTER TABLE agency_cancellation_tiers
        ADD CONSTRAINT fk_agency_cancellation_tiers_agency FOREIGN KEY (agency_id) REFERENCES agencies (id);
      ALTER TABLE client_terms_versions
        ADD CONSTRAINT fk_client_terms_versions_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_terms_versions_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_client_terms_versions_copied_from_same_agency FOREIGN KEY (copied_from_departure_id, agency_id) REFERENCES departures (id, agency_id);
      ALTER TABLE client_cancellation_tiers
        ADD CONSTRAINT fk_client_cancellation_tiers_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_cancellation_tiers_version_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES client_terms_versions (id, agency_id);
      ALTER TABLE client_payment_schedule_lines
        ADD CONSTRAINT fk_client_payment_schedule_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_client_payment_schedule_lines_version_same_agency FOREIGN KEY (client_terms_version_id, agency_id) REFERENCES client_terms_versions (id, agency_id);

      -- BKG-28: a version a booking has accepted is never changed (locked in step 6).
      CREATE FUNCTION public.reject_locked_client_terms_change() RETURNS trigger
          LANGUAGE plpgsql AS $$
      DECLARE
        version_id uuid;
      BEGIN
        IF TG_TABLE_NAME = 'client_terms_versions' THEN
          IF OLD.locked_at IS NOT NULL THEN
            RAISE EXCEPTION 'client terms version % is locked', OLD.id;
          END IF;
          RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
        END IF;
        version_id := CASE WHEN TG_OP = 'INSERT' THEN NEW.client_terms_version_id ELSE OLD.client_terms_version_id END;
        IF EXISTS (SELECT 1 FROM client_terms_versions WHERE id = version_id AND locked_at IS NOT NULL) THEN
          RAISE EXCEPTION 'client terms version % is locked', version_id;
        END IF;
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
      END;
      $$;
      CREATE TRIGGER client_terms_versions_reject_locked_change BEFORE UPDATE OR DELETE ON public.client_terms_versions
        FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();
      CREATE TRIGGER client_cancellation_tiers_reject_locked_change BEFORE INSERT OR UPDATE OR DELETE ON public.client_cancellation_tiers
        FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();
      CREATE TRIGGER client_payment_schedule_lines_reject_locked_change BEFORE INSERT OR UPDATE OR DELETE ON public.client_payment_schedule_lines
        FOR EACH ROW EXECUTE FUNCTION public.reject_locked_client_terms_change();
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # BKG-31: from a number of days before departure, a percentage of the
  # affected service's accepted charge, or a fixed amount per traveler or
  # per unit of a named service category.
  def tier_columns(table)
    table.integer :min_days_before_departure, null: false
    table.string :charge_kind, null: false
    table.decimal :percentage, precision: 7, scale: 4
    table.bigint :amount_minor_units
    table.string :currency
    table.string :service_category
    table.integer :lock_version, null: false, default: 0
    table.timestamps
  end

  def tier_checks(table_name)
    add_check_constraint table_name, "min_days_before_departure >= 0 AND lock_version >= 0", name: "#{table_name}_counters"
    add_check_constraint table_name, <<~SQL.squish, name: "#{table_name}_charge"
      (charge_kind = 'percentage' AND percentage > 0 AND percentage <= 100 AND amount_minor_units IS NULL AND currency IS NULL AND service_category IS NULL)
      OR (charge_kind = 'fixed_per_traveler' AND percentage IS NULL AND amount_minor_units >= 0 AND currency ~ '^[A-Z]{3}$' AND service_category IS NULL)
      OR (charge_kind = 'fixed_per_unit' AND percentage IS NULL AND amount_minor_units >= 0 AND currency ~ '^[A-Z]{3}$'
          AND service_category IN (#{CATEGORIES.map { |category| quote(category) }.join(", ")}))
    SQL
  end
end
