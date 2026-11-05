# frozen_string_literal: true

# Slice 1 step 1 (BKG-21): the agency's traveler types. Staff choose one for
# each traveler; whether a type uses capacity is a capacity rule (INV-39), not
# a field here.
class CreateTravelerTypes < ActiveRecord::Migration[8.1]
  DEFAULTS = [ "Adult", "Child", "Child 0–4" ].freeze

  def up
    create_table :traveler_types, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true, index: false
      table.string :name, null: false
      table.integer :position, null: false
      table.string :status, null: false, default: "active"
      table.integer :lock_version, null: false, default: 0
      table.timestamps

      table.index "agency_id, lower(name)", unique: true, name: "index_traveler_types_on_agency_and_name"
      table.index %i[agency_id position], name: "index_traveler_types_on_agency_and_position"
      table.index %i[id agency_id], unique: true, name: "index_traveler_types_on_id_and_agency_id"
      table.check_constraint "btrim(name) <> '' AND char_length(name) <= 60", name: "traveler_types_name"
      table.check_constraint "position >= 0", name: "traveler_types_position_nonnegative"
      table.check_constraint "status IN ('active', 'inactive')", name: "traveler_types_status_valid"
      table.check_constraint "lock_version >= 0", name: "traveler_types_lock_version_nonnegative"
    end

    DEFAULTS.each_with_index do |name, position|
      execute <<~SQL
        INSERT INTO traveler_types (agency_id, name, position, status, created_at, updated_at)
        SELECT agencies.id, #{quote(name)}, #{position}, 'active', now(), now() FROM agencies
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
