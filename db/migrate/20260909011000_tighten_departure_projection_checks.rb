class TightenDepartureProjectionChecks < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :departures, name: "departures_owning_office_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (status IN ('draft', 'planning') AND owning_office_status IS NOT NULL AND owning_office_status = 'active')
        OR (status = 'cancelled' AND owning_office_status IS NULL)
      SQL
      name: "departures_owning_office_projection"

    remove_check_constraint :departures, name: "departures_program_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (travel_program_id IS NULL AND travel_program_status IS NULL)
        OR (travel_program_id IS NOT NULL AND status IN ('draft', 'planning') AND travel_program_status IS NOT NULL AND travel_program_status = 'active')
        OR (travel_program_id IS NOT NULL AND status = 'cancelled' AND travel_program_status IS NULL)
      SQL
      name: "departures_program_projection"
  end

  def down
    remove_check_constraint :departures, name: "departures_owning_office_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (status IN ('draft', 'planning') AND owning_office_status = 'active')
        OR (status = 'cancelled' AND owning_office_status IS NULL)
      SQL
      name: "departures_owning_office_projection"

    remove_check_constraint :departures, name: "departures_program_projection"
    add_check_constraint :departures,
      <<~SQL.squish,
        (travel_program_id IS NULL AND travel_program_status IS NULL)
        OR (travel_program_id IS NOT NULL AND status IN ('draft', 'planning') AND travel_program_status = 'active')
        OR (travel_program_id IS NOT NULL AND status = 'cancelled' AND travel_program_status IS NULL)
      SQL
      name: "departures_program_projection"
  end
end
