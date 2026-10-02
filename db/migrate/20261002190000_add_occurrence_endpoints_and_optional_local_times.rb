# frozen_string_literal: true

class AddOccurrenceEndpointsAndOptionalLocalTimes < ActiveRecord::Migration[8.1]
  def up
    change_table :service_occurrence_definitions, bulk: true do |table|
      table.string :origin_name, limit: 160
      table.string :destination_name, limit: 160
    end

    add_check_constraint :service_occurrence_definitions,
      "origin_name IS NULL OR (btrim(origin_name) <> '' AND char_length(origin_name) <= 160)",
      name: "service_occurrence_definitions_origin_name"
    add_check_constraint :service_occurrence_definitions,
      "destination_name IS NULL OR (btrim(destination_name) <> '' AND char_length(destination_name) <= 160)",
      name: "service_occurrence_definitions_destination_name"

    remove_check_constraint :service_occurrence_definitions,
      name: "service_occurrence_definitions_times_paired"
    add_check_constraint :service_occurrence_definitions,
      "starts_on <> ends_on OR starts_at_local IS NULL OR ends_at_local IS NULL OR starts_at_local <= ends_at_local",
      name: "service_occurrence_definitions_same_day_local_times"
  end

  def down
    remove_check_constraint :service_occurrence_definitions,
      name: "service_occurrence_definitions_same_day_local_times"
    add_check_constraint :service_occurrence_definitions,
      "(starts_at_local IS NULL) = (ends_at_local IS NULL)",
      name: "service_occurrence_definitions_times_paired"
    remove_check_constraint :service_occurrence_definitions, name: "service_occurrence_definitions_destination_name"
    remove_check_constraint :service_occurrence_definitions, name: "service_occurrence_definitions_origin_name"
    remove_column :service_occurrence_definitions, :destination_name, if_exists: true
    remove_column :service_occurrence_definitions, :origin_name, if_exists: true
  end
end
