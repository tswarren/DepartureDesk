# frozen_string_literal: true

# Slice 1 step 2 (DEP-03, DEP-04, D-86): a Departure's single status becomes
# a sales status, an operating decision and a completion status. The summary
# label is derived and never stored. draft maps to Draft, Undecided, Active;
# active to Ready to sell, Undecided, Active; departed to Ready to sell,
# Undecided, Departed.
class SplitDepartureStatus < ActiveRecord::Migration[8.1]
  def up
    change_table :departures, bulk: true do |table|
      table.string :sales_status, null: false, default: "draft"
      table.string :operating_decision, null: false, default: "undecided"
      table.string :completion_status, null: false, default: "active"
    end

    execute <<~SQL
      UPDATE departures
      SET sales_status = CASE status WHEN 'draft' THEN 'draft' ELSE 'ready_to_sell' END,
          completion_status = CASE status WHEN 'departed' THEN 'departed' ELSE 'active' END
    SQL

    remove_check_constraint :departures, name: "departures_activation_completeness"
    remove_check_constraint :departures, name: "departures_departed_at_pair"
    remove_check_constraint :departures, name: "departures_non_draft_has_reference"
    remove_check_constraint :departures, name: "departures_status"
    remove_index :departures, name: "index_departures_on_agency_status_starts_on_id"
    remove_column :departures, :status

    add_check_constraint :departures, "sales_status IN ('draft', 'ready_to_sell')", name: "departures_sales_status"
    add_check_constraint :departures,
      "operating_decision IN ('undecided', 'proceed', 'postpone', 'cancel')",
      name: "departures_operating_decision"
    add_check_constraint :departures,
      "completion_status IN ('active', 'departed', 'cancelled', 'superseded')",
      name: "departures_completion_status"
    add_check_constraint :departures, <<~SQL.squish, name: "departures_ready_to_sell_completeness"
      sales_status = 'draft'
      OR (
        name IS NOT NULL AND btrim(name) <> ''
        AND starts_on IS NOT NULL
        AND ends_on IS NOT NULL
        AND time_zone IS NOT NULL AND btrim(time_zone) <> ''
        AND operating_currency IS NOT NULL
        AND responsible_agency_user_id IS NOT NULL
      )
    SQL
    add_check_constraint :departures,
      "(completion_status = 'departed') = (departed_at IS NOT NULL)",
      name: "departures_departed_at_pair"
    add_check_constraint :departures,
      "(sales_status = 'draft' AND completion_status = 'active') OR (departure_reference IS NOT NULL AND first_activated_at IS NOT NULL)",
      name: "departures_non_draft_has_reference"
    add_index :departures, %i[agency_id completion_status sales_status starts_on id],
      name: "index_departures_on_agency_statuses_starts_on_id"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
