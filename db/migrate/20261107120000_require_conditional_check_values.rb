# frozen_string_literal: true

# A PostgreSQL CHECK passes when its expression is NULL. The multi-branch
# checks on cost lines, schedule lines, cancellation tiers and client
# payment schedule lines compare nullable columns (a quantity, an amount,
# a percentage, a day count), so a NULL there passed. Each is re-added
# wrapped in COALESCE(..., false), so a missing value fails.
class RequireConditionalCheckValues < ActiveRecord::Migration[8.1]
  CHECKS = {
    cost_lines: %w[cost_lines_basis],
    schedule_lines: %w[schedule_lines_amount_kind schedule_lines_due_rule],
    agency_cancellation_tiers: %w[agency_cancellation_tiers_charge],
    client_cancellation_tiers: %w[client_cancellation_tiers_charge],
    client_payment_schedule_lines: %w[client_payment_schedule_lines_basis client_payment_schedule_lines_due_rule]
  }.freeze

  def up
    CHECKS.each do |table, names|
      names.each do |name|
        expression = select_value(<<~SQL.squish)
          SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = #{quote(name)} AND conrelid = #{quote(table.to_s)}::regclass
        SQL
        inner = expression.delete_prefix("CHECK ").strip
        execute "ALTER TABLE #{table} DROP CONSTRAINT #{name}, ADD CONSTRAINT #{name} CHECK (COALESCE(#{inner}, false))"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
