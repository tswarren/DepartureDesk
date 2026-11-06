# frozen_string_literal: true

# Slice 1 step 3b (OPS-01 to OPS-04, SUP-23): one task record whatever
# created it, with an individual owner, a due instant and its local date,
# time and zone, and a status. Overdue is derived, never stored.
class CreateTasks < ActiveRecord::Migration[8.1]
  def up
    create_table :tasks, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.string :source, null: false
      table.uuid :supplier_deadline_id
      table.string :action, null: false
      table.datetime :due_at, null: false
      table.date :due_on, null: false
      table.time :due_at_time
      table.string :due_time_zone, null: false
      table.uuid :owner_id, null: false
      table.string :status, null: false, default: "open"
      table.text :completion_note
      table.datetime :completed_at
      table.text :waiver_reason
      table.datetime :waived_at
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[owner_id status due_at], name: "index_tasks_on_owner_status_and_due_at"
      table.index %i[departure_id due_at], name: "index_tasks_on_departure_and_due_at"
      table.index :supplier_deadline_id, unique: true, name: "index_tasks_one_per_supplier_deadline"
      table.check_constraint "source IN ('supplier_deadline', 'manual')", name: "tasks_source"
      table.check_constraint "(source = 'supplier_deadline') = (supplier_deadline_id IS NOT NULL)", name: "tasks_source_record"
      table.check_constraint "btrim(action) <> '' AND char_length(action) <= 250", name: "tasks_action"
      table.check_constraint "status IN ('open', 'in_progress', 'completed', 'waived')", name: "tasks_status"
      # OPS-03: completing needs a note; waiving needs a reason.
      table.check_constraint <<~SQL.squish, name: "tasks_completed_with_note"
        (status = 'completed') = (completed_at IS NOT NULL) AND (status <> 'completed' OR btrim(coalesce(completion_note, '')) <> '')
      SQL
      table.check_constraint <<~SQL.squish, name: "tasks_waived_with_reason"
        (status = 'waived') = (waived_at IS NOT NULL) AND (status <> 'waived' OR btrim(coalesce(waiver_reason, '')) <> '')
      SQL
      table.check_constraint "lock_version >= 0", name: "tasks_lock_version"
    end
    execute <<~SQL
      ALTER TABLE tasks
        ADD CONSTRAINT fk_tasks_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_tasks_departure_same_agency FOREIGN KEY (departure_id, agency_id) REFERENCES departures (id, agency_id),
        ADD CONSTRAINT fk_tasks_supplier_deadline_same_agency
        FOREIGN KEY (supplier_deadline_id, agency_id) REFERENCES supplier_deadlines (id, agency_id),
        ADD CONSTRAINT fk_tasks_owner_same_agency FOREIGN KEY (owner_id, agency_id) REFERENCES agency_users (id, agency_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
