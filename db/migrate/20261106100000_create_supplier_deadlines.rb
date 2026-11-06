# frozen_string_literal: true

# Slice 1 step 3b (SUP-22 to SUP-25, SET-10): an arrangement's supplier
# deadlines, each with the supplier's local date, optional time and zone,
# and the instant it resolves to, stored when recorded.
class CreateSupplierDeadlines < ActiveRecord::Migration[8.1]
  TYPES = %w[option_release deposit_payment names_submission rooming_list ticketing final_count cancellation_tier_cutoff other].freeze

  def up
    create_table :supplier_deadlines, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :inventory_group_id
      table.string :deadline_type, null: false
      table.boolean :actionable, null: false
      table.string :description, null: false
      table.date :due_on, null: false
      table.time :due_at_time
      table.string :time_zone, null: false
      table.datetime :resolved_at, null: false
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index %i[supplier_arrangement_id resolved_at], name: "index_supplier_deadlines_on_arrangement_and_resolved_at"
      table.index %i[id agency_id], unique: true, name: "index_supplier_deadlines_on_id_and_agency_id"
      table.check_constraint "deadline_type IN (#{TYPES.map { |type| quote(type) }.join(", ")})", name: "supplier_deadlines_type"
      table.check_constraint "btrim(description) <> '' AND char_length(description) <= 200", name: "supplier_deadlines_description"
      table.check_constraint "btrim(time_zone) <> ''", name: "supplier_deadlines_time_zone"
      table.check_constraint "lock_version >= 0", name: "supplier_deadlines_lock_version"
    end
    execute <<~SQL
      ALTER TABLE supplier_deadlines
        ADD CONSTRAINT fk_supplier_deadlines_agency FOREIGN KEY (agency_id) REFERENCES agencies (id),
        ADD CONSTRAINT fk_supplier_deadlines_arrangement_same_agency
        FOREIGN KEY (supplier_arrangement_id, agency_id) REFERENCES supplier_arrangements (id, agency_id),
        ADD CONSTRAINT fk_supplier_deadlines_group_of_arrangement
        FOREIGN KEY (inventory_group_id, supplier_arrangement_id) REFERENCES inventory_groups (id, supplier_arrangement_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
