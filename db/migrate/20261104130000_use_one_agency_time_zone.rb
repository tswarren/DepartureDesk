# frozen_string_literal: true

# Slice 1 step 1 (ADR 0016): offices carry no time zone, and a Departure no
# longer needs a responsible office to leave draft.
class UseOneAgencyTimeZone < ActiveRecord::Migration[8.1]
  def up
    remove_column :offices, :default_timezone

    remove_check_constraint :departures, name: "departures_activation_completeness"
    add_check_constraint :departures, <<~SQL.squish, name: "departures_activation_completeness"
      status = 'draft'
      OR (
        name IS NOT NULL AND btrim(name) <> ''
        AND starts_on IS NOT NULL
        AND ends_on IS NOT NULL
        AND time_zone IS NOT NULL AND btrim(time_zone) <> ''
        AND operating_currency IS NOT NULL
        AND responsible_agency_user_id IS NOT NULL
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
