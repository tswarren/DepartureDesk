# frozen_string_literal: true

# Slice 1 step 2 (DEP-01, BKG-09, CMN-10, SET-14): a Departure may override
# the agency's client hold duration and installment buffer. Blank means the
# agency default applies; a value is recorded only when staff enter one.
class AddDepartureOverrides < ActiveRecord::Migration[8.1]
  def change
    change_table :departures, bulk: true do |table|
      table.integer :hold_duration_days
      table.integer :installment_buffer_days
    end
    add_check_constraint :departures, "hold_duration_days IS NULL OR hold_duration_days >= 1", name: "departures_hold_duration_positive"
    add_check_constraint :departures, "installment_buffer_days IS NULL OR installment_buffer_days >= 0", name: "departures_installment_buffer_nonnegative"
  end
end
