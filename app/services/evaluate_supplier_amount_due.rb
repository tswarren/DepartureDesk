# frozen_string_literal: true

class EvaluateSupplierAmountDue
  Line = Data.define(:component_id, :label, :quantity, :rate_minor_units, :amount_minor_units, :pool_id)
  Result = Data.define(:definition_id, :currency, :due_on, :total_minor_units, :lines) do
    def late_coach?
      false
    end
  end

  def initialize(version:, definition: nil)
    @version = version
    @definition = definition || version.supplier_amount_due_definitions.first
  end

  def call
    return nil if @definition.nil?

    due_on = Date.iso8601(@definition.rule_parameters.fetch("date"))
    lines = @definition.supplier_amount_due_contributors.order(:position, :id).map do |contributor|
      component = contributor.supplier_cost_component
      pool = CapacityPool.find(component.quantity_capacity_pool_id)
      quantity = BillableCapacityQuantity.quantity_at(pool:, version: @version, due_on:)
      rate = component.amount_minor_units.to_i
      Line.new(
        component_id: component.id,
        label: component.supplier_cost_definition.supplier_cost_source.label,
        quantity:,
        rate_minor_units: rate,
        amount_minor_units: quantity * rate,
        pool_id: pool.id
      )
    end
    Result.new(
      definition_id: @definition.id,
      currency: @definition.currency,
      due_on:,
      total_minor_units: lines.sum(&:amount_minor_units),
      lines:
    )
  end
end
