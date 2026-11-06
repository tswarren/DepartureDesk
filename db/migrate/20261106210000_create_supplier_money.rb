# frozen_string_literal: true

# Slice 1 step 4 (SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11, SMN-13,
# SMN-14, SMN-17, SUP-13, D-75, D-81): cost lines (what a commitment costs
# in total), schedule lines (when portions fall due), trigger events, and
# amounts due (what is payable now). Money is minor units in the
# arrangement currency (ADR 0001).
class CreateSupplierMoney < ActiveRecord::Migration[8.1]
  TRIGGERS = %w[
    arrangement_confirmed names_submitted client_booking_confirmed rooming_list_submitted final_count_submitted
    tickets_issued supplier_invoice_received service_date other
  ].freeze

  def up
    create_table :cost_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.string :scope, null: false
      table.uuid :inventory_group_id
      table.string :description, null: false
      table.string :basis, null: false
      table.bigint :rate_minor_units
      table.integer :quantity
      table.decimal :percentage, precision: 7, scale: 4
      table.uuid :base_cost_line_id
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.string :stage, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :supplier_arrangement_id, name: "index_cost_lines_on_arrangement"
      table.index %i[id agency_id], unique: true, name: "index_cost_lines_on_id_and_agency_id"
      table.index %i[id supplier_arrangement_id], unique: true, name: "index_cost_lines_on_id_and_arrangement"
      table.check_constraint "scope IN ('arrangement', 'inventory_group', 'unit_shells')", name: "cost_lines_scope"
      table.check_constraint "(scope = 'inventory_group') = (inventory_group_id IS NOT NULL)", name: "cost_lines_group_scope"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 200", name: "cost_lines_description"
      table.check_constraint "stage IN ('estimated', 'committed')", name: "cost_lines_stage"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "cost_lines_currency"
      # SMN-02: a fixed amount, a fixed amount per unit, person or night, or a percentage of a named cost line.
      table.check_constraint <<~SQL.squish, name: "cost_lines_basis"
        (basis = 'fixed' AND rate_minor_units IS NOT NULL AND quantity IS NULL AND percentage IS NULL AND base_cost_line_id IS NULL)
        OR (basis IN ('per_unit', 'per_person', 'per_night') AND rate_minor_units IS NOT NULL AND quantity >= 1 AND percentage IS NULL AND base_cost_line_id IS NULL)
        OR (basis = 'percentage' AND rate_minor_units IS NULL AND quantity IS NULL AND percentage > 0 AND percentage <= 100 AND base_cost_line_id IS NOT NULL)
      SQL
      table.check_constraint "amount_minor_units >= 0 AND (rate_minor_units IS NULL OR rate_minor_units >= 0)", name: "cost_lines_amounts"
      table.check_constraint "base_cost_line_id IS NULL OR base_cost_line_id <> id", name: "cost_lines_base_not_self"
      table.check_constraint "lock_version >= 0", name: "cost_lines_lock_version"
    end

    create_table :cost_line_shells, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :cost_line_id, null: false
      table.uuid :unit_shell_id, null: false
      table.timestamps

      table.index %i[cost_line_id unit_shell_id], unique: true, name: "index_cost_line_shells_on_line_and_shell"
      table.index :unit_shell_id, name: "index_cost_line_shells_on_shell"
    end

    create_table :schedule_lines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :cost_line_id
      table.uuid :supplier_deadline_id
      table.uuid :inventory_group_id
      table.string :description, null: false
      table.string :amount_kind, null: false
      table.bigint :amount_minor_units
      table.bigint :rate_minor_units
      table.decimal :percentage, precision: 7, scale: 4
      table.string :currency, null: false
      table.string :due_rule, null: false
      table.date :due_on
      table.string :trigger_type
      table.integer :days_after
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index :supplier_arrangement_id, name: "index_schedule_lines_on_arrangement"
      table.index %i[id agency_id], unique: true, name: "index_schedule_lines_on_id_and_agency_id"
      table.index %i[id supplier_arrangement_id], unique: true, name: "index_schedule_lines_on_id_and_arrangement"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 200", name: "schedule_lines_description"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "schedule_lines_currency"
      # SMN-04 and SMN-10: a fixed amount, a percentage of its cost line, an amount per unit times a count, or one amount per shell.
      table.check_constraint <<~SQL.squish, name: "schedule_lines_amount_kind"
        (amount_kind = 'fixed' AND amount_minor_units >= 0 AND rate_minor_units IS NULL AND percentage IS NULL)
        OR (amount_kind = 'percentage_of_cost_line' AND cost_line_id IS NOT NULL AND percentage > 0 AND percentage <= 100 AND amount_minor_units IS NULL AND rate_minor_units IS NULL)
        OR (amount_kind IN ('per_unit_count', 'per_shell') AND rate_minor_units >= 0 AND amount_minor_units IS NULL AND percentage IS NULL)
      SQL
      table.check_constraint "trigger_type IS NULL OR trigger_type IN (#{TRIGGERS.map { |trigger| quote(trigger) }.join(", ")})", name: "schedule_lines_trigger_type"
      # SMN-04: a fixed date, an event, a period after an event, or the earlier of an event and a date.
      table.check_constraint <<~SQL.squish, name: "schedule_lines_due_rule"
        (due_rule = 'fixed_date' AND due_on IS NOT NULL AND trigger_type IS NULL AND days_after IS NULL)
        OR (due_rule = 'event' AND due_on IS NULL AND trigger_type IS NOT NULL AND days_after IS NULL)
        OR (due_rule = 'event_plus_days' AND due_on IS NULL AND trigger_type IS NOT NULL AND days_after >= 1)
        OR (due_rule = 'earlier_of' AND due_on IS NOT NULL AND trigger_type IS NOT NULL AND days_after IS NULL)
      SQL
      table.check_constraint "lock_version >= 0", name: "schedule_lines_lock_version"
    end

    create_table :trigger_events, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.string :event_type, null: false
      table.date :occurred_on, null: false
      table.integer :count
      table.string :reference
      table.uuid :recorded_by_id
      table.string :recorded_by_identifier
      table.datetime :recorded_at, null: false

      table.index %i[supplier_arrangement_id event_type occurred_on], name: "index_trigger_events_on_arrangement_type_and_date"
      table.index %i[id agency_id], unique: true, name: "index_trigger_events_on_id_and_agency_id"
      table.check_constraint "event_type IN (#{TRIGGERS.map { |trigger| quote(trigger) }.join(", ")})", name: "trigger_events_type"
      table.check_constraint "count IS NULL OR count >= 0", name: "trigger_events_count"
      table.check_constraint "reference IS NULL OR (btrim(reference) <> '' AND char_length(reference) <= 120)", name: "trigger_events_reference"
      table.check_constraint "(recorded_by_id IS NULL) <> (recorded_by_identifier IS NULL)", name: "trigger_events_recorded_by"
    end

    create_table :amounts_due, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :schedule_line_id
      table.uuid :unit_shell_id
      table.uuid :trigger_event_id
      table.string :description, null: false
      table.bigint :amount_minor_units, null: false
      table.string :currency, null: false
      table.date :due_on, null: false
      table.integer :quantity
      table.bigint :rate_minor_units
      table.decimal :percentage, precision: 7, scale: 4
      table.bigint :base_minor_units
      table.uuid :posted_by_id
      table.string :posted_by_identifier
      table.datetime :posted_at, null: false

      table.index :supplier_arrangement_id, name: "index_amounts_due_on_arrangement"
      table.index %i[agency_id due_on], name: "index_amounts_due_on_agency_and_due_on"
      table.index %i[id agency_id], unique: true, name: "index_amounts_due_on_id_and_agency_id"
      # SMN-10, D-81: at most one amount per shell per schedule line.
      table.index %i[schedule_line_id unit_shell_id], unique: true, nulls_not_distinct: true, where: "schedule_line_id IS NOT NULL",
        name: "index_amounts_due_one_per_shell_per_schedule_line"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 200", name: "amounts_due_description"
      table.check_constraint "amount_minor_units >= 0", name: "amounts_due_amount"
      table.check_constraint "currency ~ '^[A-Z]{3}$'", name: "amounts_due_currency"
      table.check_constraint "unit_shell_id IS NULL OR schedule_line_id IS NOT NULL", name: "amounts_due_shell_needs_line"
      table.check_constraint "(posted_by_id IS NULL) <> (posted_by_identifier IS NULL)", name: "amounts_due_posted_by"
    end

    execute <<~SQL
      ALTER TABLE cost_lines
        ADD CONSTRAINT fk_cost_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_cost_lines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_cost_lines_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES supplier_arrangements (id, currency),
        ADD CONSTRAINT fk_cost_lines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES inventory_groups (id, supplier_arrangement_id),
        ADD CONSTRAINT fk_cost_lines_base_of_arrangement FOREIGN KEY (base_cost_line_id, supplier_arrangement_id) REFERENCES cost_lines (id, supplier_arrangement_id);
      ALTER TABLE cost_line_shells
        ADD CONSTRAINT fk_cost_line_shells_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_cost_line_shells_line_same_agency FOREIGN KEY (cost_line_id, agency_id) REFERENCES cost_lines (id, agency_id),
        ADD CONSTRAINT fk_cost_line_shells_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES unit_shells (id, agency_id);
      ALTER TABLE schedule_lines
        ADD CONSTRAINT fk_schedule_lines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_schedule_lines_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_schedule_lines_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES supplier_arrangements (id, currency),
        ADD CONSTRAINT fk_schedule_lines_cost_line_of_arrangement FOREIGN KEY (cost_line_id, supplier_arrangement_id) REFERENCES cost_lines (id, supplier_arrangement_id),
        ADD CONSTRAINT fk_schedule_lines_group_of_arrangement FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES inventory_groups (id, supplier_arrangement_id),
        ADD CONSTRAINT fk_schedule_lines_deadline_same_agency FOREIGN KEY (supplier_deadline_id, agency_id) REFERENCES supplier_deadlines (id, agency_id);
      ALTER TABLE trigger_events
        ADD CONSTRAINT fk_trigger_events_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_trigger_events_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_trigger_events_recorder_same_agency FOREIGN KEY (recorded_by_id, agency_id) REFERENCES agency_users (id, agency_id);
      ALTER TABLE amounts_due
        ADD CONSTRAINT fk_amounts_due_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_amounts_due_arrangement_same_agency FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_amounts_due_arrangement_currency FOREIGN KEY (supplier_arrangement_id, currency) REFERENCES supplier_arrangements (id, currency),
        ADD CONSTRAINT fk_amounts_due_schedule_line_of_arrangement FOREIGN KEY (schedule_line_id, supplier_arrangement_id) REFERENCES schedule_lines (id, supplier_arrangement_id),
        ADD CONSTRAINT fk_amounts_due_shell_same_agency FOREIGN KEY (unit_shell_id, agency_id) REFERENCES unit_shells (id, agency_id),
        ADD CONSTRAINT fk_amounts_due_event_same_agency FOREIGN KEY (trigger_event_id, agency_id) REFERENCES trigger_events (id, agency_id),
        ADD CONSTRAINT fk_amounts_due_poster_same_agency FOREIGN KEY (posted_by_id, agency_id) REFERENCES agency_users (id, agency_id);

      -- SMN-06, SMN-13, SMN-15: trigger events and posted amounts are never
      -- changed or undone; adjustments with a reason come with a later step.
      CREATE FUNCTION public.reject_supplier_money_mutation() RETURNS trigger
          LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION '% rows are append-only', TG_TABLE_NAME;
      END;
      $$;
      CREATE TRIGGER trigger_events_reject_mutation BEFORE DELETE OR UPDATE ON public.trigger_events
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();
      CREATE TRIGGER amounts_due_reject_mutation BEFORE DELETE OR UPDATE ON public.amounts_due
        FOR EACH ROW EXECUTE FUNCTION public.reject_supplier_money_mutation();
    SQL

    # SMN-17: a schedule line or a direct amount due can own its payment task.
    add_column :tasks, :schedule_line_id, :uuid
    add_column :tasks, :amount_due_id, :uuid
    remove_check_constraint :tasks, name: "tasks_source"
    remove_check_constraint :tasks, name: "tasks_source_record"
    add_check_constraint :tasks, "source IN ('supplier_deadline', 'schedule_line', 'amount_due', 'manual')", name: "tasks_source"
    add_check_constraint :tasks, <<~SQL.squish, name: "tasks_source_record"
      (source = 'supplier_deadline') = (supplier_deadline_id IS NOT NULL)
      AND (source = 'schedule_line') = (schedule_line_id IS NOT NULL)
      AND (source = 'amount_due') = (amount_due_id IS NOT NULL)
    SQL
    add_index :tasks, :schedule_line_id, unique: true, name: "index_tasks_one_per_schedule_line"
    add_index :tasks, :amount_due_id, unique: true, name: "index_tasks_one_per_amount_due"
    execute <<~SQL
      ALTER TABLE tasks
        ADD CONSTRAINT fk_tasks_schedule_line_same_agency FOREIGN KEY (schedule_line_id, agency_id) REFERENCES schedule_lines (id, agency_id),
        ADD CONSTRAINT fk_tasks_amount_due_same_agency FOREIGN KEY (amount_due_id, agency_id) REFERENCES amounts_due (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
