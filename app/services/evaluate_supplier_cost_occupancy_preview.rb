# Read-only occupancy illustrations for Supplier cost review. Reuses
# EvaluateSupplierCostForecast arithmetic with in-memory profile scoping.
class EvaluateSupplierCostOccupancyPreview
  Result = Data.define(
    :applicable, :context_label, :empty_reason, :profiles,
    :combined_totals, :illustrated_totals, :rounding_differences, :rounding_explanation,
    :currency
  )

  def initialize(agency:, departure:, arrangement:, source:, definition:, assumption:,
    item_definition: nil, occurrence_definition: nil, resource_definition: nil)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @source = source
    @definition = definition
    @assumption = assumption
    @item_definition = item_definition
    @occurrence_definition = occurrence_definition
    @resource_definition = resource_definition
  end

  # Pass +precomputed+ from EvaluateSupplierCostForecast#call_for_definition_review
  # to avoid a second cost-graph preload on the review path.
  def call(precomputed: nil)
    context_label = exact_context_label
    unless @source.arrangement_item_id
      return empty_result(
        applicable: false,
        context_label: context_label,
        empty_reason: "Occupancy profiles apply to Item-scoped cost sources."
      )
    end

    unless @assumption
      return empty_result(
        applicable: true,
        context_label: context_label,
        empty_reason:
          "No planning quantities exist for this exact context (#{context_label}). " \
          "Add an occupancy assumption that matches this Occurrence and Resource."
      )
    end

    profiles = @assumption.supplier_cost_occupancy_profiles
    if profiles.empty?
      return empty_result(
        applicable: true,
        context_label: context_label,
        empty_reason:
          "No occupancy profiles exist for this exact context (#{context_label}). " \
          "Add profiles under Planning quantities for this Occurrence and Resource."
      )
    end

    preview = precomputed || EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: @departure,
      arrangement: @arrangement,
      probe_definition: @definition
    ).occupancy_preview(source: @source, assumption: @assumption)

    Result.new(
      applicable: true,
      context_label: context_label,
      empty_reason: nil,
      profiles: preview.profiles,
      combined_totals: preview.combined_totals,
      illustrated_totals: preview.illustrated_totals,
      rounding_differences: preview.rounding_differences,
      rounding_explanation: preview.rounding_explanation,
      currency: @definition.currency
    )
  end

  private

  def empty_result(applicable:, context_label:, empty_reason:)
    Result.new(
      applicable: applicable,
      context_label: context_label,
      empty_reason: empty_reason,
      profiles: [],
      combined_totals: EvaluateSupplierCostForecast::ZERO_TOTALS,
      illustrated_totals: EvaluateSupplierCostForecast::ZERO_TOTALS,
      rounding_differences: {},
      rounding_explanation: nil,
      currency: @definition.currency
    )
  end

  def exact_context_label
    item_name = @item_definition&.name || "Item"
    occurrence_name = if @source.service_occurrence_id
      @occurrence_definition&.name || "selected Occurrence"
    else
      "Entire Item"
    end
    resource_name = if @source.supplier_resource_id
      @resource_definition&.name || "selected Resource"
    else
      "All resources"
    end
    "#{item_name} · #{occurrence_name} · #{resource_name}"
  end
end
