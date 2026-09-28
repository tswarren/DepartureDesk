# frozen_string_literal: true

# Suggests the initial-deposit due date from the group creation date.
# A saved due date is left unchanged when the creation date later changes.
module CruiseInitialDepositDueDate
  LAG_DAYS = 30

  module_function

  def suggested_on(group_creation_date)
    return nil if group_creation_date.blank?

    group_creation_date.to_date + LAG_DAYS
  end

  def mismatch?(saved_on:, group_creation_date:)
    suggested = suggested_on(group_creation_date)
    return false if suggested.nil? || saved_on.blank?

    saved_on.to_date != suggested
  end

  def saved_fixed_dates(version)
    version.supplier_deposit_requirement_definitions.filter_map do |definition|
      next unless definition.rule_shape.to_s == "fixed_date"

      raw = definition.rule_parameters.is_a?(Hash) ? definition.rule_parameters["date"] : nil
      next if raw.blank?

      Date.iso8601(raw.to_s)
    rescue ArgumentError
      nil
    end
  end
end
