# frozen_string_literal: true

# Slice 1 step 4 (SUP-21, SMN-32): what a rate line's commission rate
# applies to, as the supplier states it. Existing rows take the default
# without an update, so the freeze trigger is not involved.
class AddCommissionBaseToSupplierRateLines < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_rate_lines, :commission_base, :string, null: false, default: "base_fare"
    add_check_constraint :supplier_rate_lines, "commission_base IN ('base_fare', 'base_fare_less_discount')", name: "supplier_rate_lines_commission_base"
  end
end
