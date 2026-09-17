class EvaluateSupplierCostForecast
  Totals = Data.define(
    :supplier_charges_minor_units, :supplier_credits_minor_units,
    :forecast_supplier_cost_minor_units, :expected_commission_minor_units,
    :expected_net_cost_after_commission_minor_units
  )
  ComponentResult = Data.define(
    :component_id, :label, :position, :calculation_kind, :economic_role,
    :rounded_minor_units, :rounding_mode, :rounding_boundary, :quantity,
    :rate, :base_links, :pass_through, :formula
  )
  SourceResult = Data.define(
    :source_id, :label, :context, :charging_supplier_id, :selected_stage,
    :selection_reason, :complete, :definition_id, :currency, :components,
    :totals, :zero_cost_reason, :warnings
  )
  ArrangementResult = Data.define(
    :arrangement_id, :version_id, :currency, :complete, :subtotal_label,
    :totals, :sources, :uncovered_item_ids, :incomplete_source_ids, :warnings
  )
  Result = Data.define(
    :departure_id, :currency, :complete, :subtotal_label, :totals,
    :arrangements, :uncovered_item_ids, :incomplete_source_ids, :warnings
  )

  ZERO_TOTALS = Totals.new(
    supplier_charges_minor_units: 0,
    supplier_credits_minor_units: 0,
    forecast_supplier_cost_minor_units: 0,
    expected_commission_minor_units: 0,
    expected_net_cost_after_commission_minor_units: 0
  )

  def initialize(agency:, departure:, arrangement: nil, probe_definition: nil)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @probe_definition = probe_definition
  end

  def call(isolated: true)
    if isolated
      ActiveRecord::Base.transaction(isolation: :repeatable_read) do
        ActiveRecord::Base.connection.execute("SET TRANSACTION READ ONLY")
        preload!
        calculate
      end
    else
      preload!
      calculate
    end
  end

  private

  def preload!
    @loaded_departure = @agency.departures.find(record_id(@departure))
    scope = @agency.supplier_arrangements.where(departure_id: @loaded_departure.id)
    if @arrangement
      scope = scope.where(id: record_id(@arrangement))
    else
      # Departure-level projection excludes abandoned Arrangements. An explicit
      # Arrangement evaluation may still read retained abandoned terms.
      scope = scope.where.not(status: "abandoned")
    end
    @arrangements = scope.order(:created_at, :id).to_a
    raise ActiveRecord::RecordNotFound if @arrangement && @arrangements.empty?

    arrangement_ids = @arrangements.map(&:id)
    @versions = SupplierArrangementVersion.where(
      agency_id: @agency.id, departure_id: @loaded_departure.id,
      supplier_arrangement_id: arrangement_ids, version_number: 1
    ).order(:supplier_arrangement_id, :version_number).to_a
    version_ids = @versions.map(&:id)

    @item_definitions = ArrangementItemDefinition.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).order(:position, :id).to_a
    @occurrence_definitions = ServiceOccurrenceDefinition.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).to_a
    @resource_definitions = SupplierResourceDefinition.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).to_a
    @sources = SupplierCostSource.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).order(:position, :id).to_a
    @definitions = SupplierCostDefinition.includes(:supplier_cost_source).where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).to_a
    definition_ids = @definitions.map(&:id)
    @components = SupplierCostComponent.where(
      agency_id: @agency.id, supplier_cost_definition_id: definition_ids
    ).includes(:supplier_cost_component_bases).order(:position, :id).to_a
    @categories = SupplierCostParticipantCategory.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).to_a
    @assumptions = SupplierCostUsageAssumption.where(
      agency_id: @agency.id, supplier_arrangement_version_id: version_ids
    ).to_a
    assumption_ids = @assumptions.map(&:id)
    @profiles = SupplierCostOccupancyProfile.where(
      agency_id: @agency.id, supplier_cost_usage_assumption_id: assumption_ids
    ).order(:position, :id).to_a
    profile_ids = @profiles.map(&:id)
    @profile_positions = SupplierCostOccupancyProfilePosition.where(
      agency_id: @agency.id, supplier_cost_occupancy_profile_id: profile_ids
    ).order(:occupancy_position, :id).to_a

    supplier_ids = @arrangements.map(&:contracting_supplier_id) + @sources.map(&:charging_supplier_id) +
      @item_definitions.filter_map(&:default_service_provider_id) +
      @occurrence_definitions.filter_map(&:service_provider_id)
    @suppliers_by_id = @agency.suppliers.where(id: supplier_ids.uniq).index_by(&:id)
    @versions_by_arrangement = @versions.index_by(&:supplier_arrangement_id)
    @items_by_version = @item_definitions.group_by(&:supplier_arrangement_version_id)
    @occurrences_by_version = @occurrence_definitions.group_by(&:supplier_arrangement_version_id)
    @resources_by_version = @resource_definitions.group_by(&:supplier_arrangement_version_id)
    @sources_by_version = @sources.group_by(&:supplier_arrangement_version_id)
    @definitions_by_source = @definitions.group_by(&:supplier_cost_source_id)
    @components_by_definition = @components.group_by(&:supplier_cost_definition_id)
    @category_labels = @categories.to_h { |category| [ category.id, category.label ] }
    @assumptions_by_context = @assumptions.index_by { |assumption| context_key(assumption) }
    @profiles_by_assumption = @profiles.group_by(&:supplier_cost_usage_assumption_id)
    @positions_by_profile = @profile_positions.group_by(&:supplier_cost_occupancy_profile_id)
  end

  def calculate
    arrangements = @arrangements.map { |arrangement| evaluate_arrangement(arrangement) }
    complete = arrangements.all?(&:complete)
    Result.new(
      departure_id: @loaded_departure.id,
      currency: @loaded_departure.operating_currency,
      complete: complete,
      subtotal_label: complete ? "Forecast total" : "Known forecast subtotal",
      totals: sum_totals(arrangements.map(&:totals)),
      arrangements: arrangements,
      uncovered_item_ids: arrangements.flat_map(&:uncovered_item_ids),
      incomplete_source_ids: arrangements.flat_map(&:incomplete_source_ids),
      warnings: arrangements.flat_map(&:warnings)
    )
  end

  def evaluate_arrangement(arrangement)
    version = @versions_by_arrangement[arrangement.id]
    unless version
      warning = warning(:missing_version, "The Arrangement has no current cost-planning version.")
      return ArrangementResult.new(
        arrangement_id: arrangement.id, version_id: nil, currency: @loaded_departure.operating_currency,
        complete: false, subtotal_label: "Known forecast subtotal", totals: ZERO_TOTALS,
        sources: [], uncovered_item_ids: [], incomplete_source_ids: [], warnings: [ warning ]
      )
    end

    item_ids = Array(@items_by_version[version.id]).map(&:arrangement_item_id)
    sources = Array(@sources_by_version[version.id]).map do |source|
      evaluate_source(arrangement, version, source)
    end
    covered_item_ids = Array(@sources_by_version[version.id]).filter_map(&:arrangement_item_id).uniq
    uncovered = item_ids - covered_item_ids
    incomplete = sources.reject(&:complete)
    warnings = []
    warnings << warning(:uncovered_items, "Every retained Item requires an Item-scoped cost source.") if uncovered.any?
    complete = uncovered.empty? && incomplete.empty?

    ArrangementResult.new(
      arrangement_id: arrangement.id,
      version_id: version.id,
      currency: @loaded_departure.operating_currency,
      complete: complete,
      subtotal_label: complete ? "Forecast total" : "Known forecast subtotal",
      totals: sum_totals(sources.select(&:complete).map(&:totals)),
      sources: sources,
      uncovered_item_ids: uncovered,
      incomplete_source_ids: incomplete.map(&:source_id),
      warnings: warnings + sources.flat_map(&:warnings)
    )
  end

  def evaluate_source(arrangement, version, source)
    warnings = context_warnings(arrangement, version, source)
    definitions = Array(@definitions_by_source[source.id])
    contracted = definitions.find { |definition| definition.contracted? && definition.forecast_ready? }
    estimate = definitions.find { |definition| definition.estimate? && definition.forecast_ready? }
    selected = if @probe_definition && @probe_definition.supplier_cost_source_id == source.id
      @probe_definition
    else
      contracted || estimate
    end
    selection_reason = if @probe_definition && selected.equal?(@probe_definition)
      "Readiness probe of the submitted definition."
    elsif contracted
      "Forecast-ready contracted terms supersede the estimate."
    elsif estimate
      "No forecast-ready contracted definition; using forecast-ready estimate."
    else
      "No forecast-ready contracted or estimate definition."
    end

    unless selected
      warnings << warning(:no_selected_stage, selection_reason)
      return source_result(source, selected, selection_reason, false, [], ZERO_TOTALS, warnings)
    end

    components = Array(@components_by_definition[selected.id])
    unless @probe_definition&.id == selected.id
      fingerprint = SupplierCostDefinitionFingerprint.call(
        selected, components: components, category_labels: @category_labels
      )
      unless ActiveSupport::SecurityUtils.secure_compare(selected.readiness_fingerprint.to_s, fingerprint)
        warnings << warning(:invalid_readiness_fingerprint, "Readiness no longer matches the current term facts.")
      end
    end
    if selected.currency != @loaded_departure.operating_currency
      warnings << warning(:currency_mismatch, "Definition currency does not match the Departure operating currency.")
    end
    if selected.calculated? && components.empty?
      warnings << warning(:empty_definition, "A calculated definition requires at least one component.")
    end
    if selected.zero_cost? && components.any?
      warnings << warning(:invalid_zero_cost, "A zero-cost definition cannot contain components.")
    end
    return source_result(source, selected, selection_reason, false, [], ZERO_TOTALS, warnings) if warnings.any?

    if selected.zero_cost?
      return source_result(source, selected, selection_reason, true, [], ZERO_TOTALS, [])
    end

    assumption = @assumptions_by_context[context_key(source)]
    component_results, evaluation_warnings = evaluate_components(components, assumption)
    warnings.concat(evaluation_warnings)
    totals = totals_for(component_results)
    if totals.forecast_supplier_cost_minor_units.negative?
      warnings << warning(:negative_supplier_cost, "Forecast Supplier cost cannot be negative.")
    end
    if totals.expected_net_cost_after_commission_minor_units.negative?
      warnings << warning(:negative_net_cost, "Expected net cost after commission cannot be negative.")
    end
    source_result(source, selected, selection_reason, warnings.empty?, component_results, totals, warnings)
  end

  def evaluate_components(components, assumption)
    results = []
    warnings = []
    by_id = {}
    components.sort_by { |component| [ component.position, component.id ] }.each do |component|
      result = evaluate_component(component, assumption, by_id)
      results << result
      by_id[component.id] = result
    rescue MissingInput => error
      warnings << warning(error.code, error.message, component_id: component.id)
      break
    end
    [ results, warnings ]
  end

  def evaluate_component(component, assumption, earlier)
    quantity = nil
    base_links = component.supplier_cost_component_bases.sort_by { |base| [ base.position, base.id ] }.map do |base|
      result = earlier[base.base_component_id] ||
        raise(MissingInput.new(:invalid_component_base, "A component base is missing or is not earlier."))
      {
        base_component_id: base.base_component_id,
        direction: base.direction,
        rounded_minor_units: result.rounded_minor_units
      }
    end
    monetary_base = base_links.sum do |base|
      base[:direction] == "subtract" ? -base[:rounded_minor_units] : base[:rounded_minor_units]
    end

    unrounded, formula = case component.calculation_kind
    when "fixed"
      [ BigDecimal(component.amount_minor_units.to_s), { amount_minor_units: component.amount_minor_units } ]
    when "unit_rate"
      quantity = quantity_for(component, assumption)
      [
        BigDecimal(component.amount_minor_units.to_s) * quantity,
        { unit_rate_minor_units: component.amount_minor_units, evaluated_quantity: quantity }
      ]
    when "percentage"
      raise MissingInput.new(:invalid_percentage_base, "A percentage base cannot be negative.") if monetary_base.negative?
      value = BigDecimal(monetary_base.to_s) * component.rate
      value /= (BigDecimal("1") + component.rate) if component.included?
      [
        value,
        {
          monetary_base_minor_units: monetary_base, rate: component.rate.to_s("F"),
          treatment: component.percentage_treatment
        }
      ]
    when "minimum_amount_shortfall"
      raise MissingInput.new(:invalid_minimum_amount_base, "A minimum-amount base cannot be negative.") if monetary_base.negative?
      value = [ component.minimum_minor_units - monetary_base, 0 ].max
      [
        BigDecimal(value.to_s),
        {
          monetary_base_minor_units: monetary_base,
          minimum_minor_units: component.minimum_minor_units,
          shortfall_minor_units: value
        }
      ]
    when "minimum_quantity_shortfall"
      base = component.supplier_cost_component_bases.first
      base_component = components_base_record(component, base)
      unless base_component&.unit_rate? && compatible_quantity_formula?(component, base_component)
        raise MissingInput.new(:invalid_quantity_minimum_base, "A quantity minimum requires one compatible earlier unit-rate base.")
      end
      quantity = quantity_for(component, assumption)
      missing = [ component.minimum_quantity - quantity, 0 ].max
      [
        BigDecimal((missing * base_component.amount_minor_units).to_s),
        {
          planned_quantity: quantity,
          minimum_billed_quantity: component.minimum_quantity,
          missing_billed_quantity: missing,
          unit_rate_minor_units: base_component.amount_minor_units,
          monetary_shortfall_minor_units: missing * base_component.amount_minor_units
        }
      ]
    else
      raise MissingInput.new(:unsupported_calculation_kind, "The calculation kind is not supported.")
    end

    ComponentResult.new(
      component_id: component.id,
      label: component.label,
      position: component.position,
      calculation_kind: component.calculation_kind,
      economic_role: component.economic_role,
      rounded_minor_units: round_minor_units(unrounded),
      rounding_mode: "half_up",
      rounding_boundary: "currency_minor_unit",
      quantity: quantity,
      rate: component.rate&.to_s("F"),
      base_links: base_links,
      pass_through: component.pass_through,
      formula: formula.merge(unrounded_minor_units: unrounded.to_s("F"))
    )
  end

  def quantity_for(component, assumption, basis: component.quantity_basis)
    raise MissingInput.new(:missing_usage_assumption, "Usage assumptions are missing for this cost context.") unless assumption

    profiles = Array(@profiles_by_assumption[assumption.id])
    positions = profiles.flat_map do |profile|
      Array(@positions_by_profile[profile.id]).map { |position| [ profile, position ] }
    end
    filtered_positions = positions.select do |_profile, position|
      category_match = component.participant_category_id.nil? ||
        position.participant_category_id == component.participant_category_id
      range_match = component.occupancy_position_from.nil? ||
        (position.occupancy_position >= component.occupancy_position_from &&
          (component.occupancy_position_to.nil? || position.occupancy_position <= component.occupancy_position_to))
      category_match && range_match
    end
    nights = assumption.expected_billable_nights

    case basis
    when "resource_units"
      profiles.any? ? profiles.sum(&:resource_unit_count) :
        required_quantity(assumption.expected_resource_units, :missing_resource_units, "Expected resource units are missing.")
    when "persons"
      if component.participant_category_id
        require_profiles!(profiles)
        filtered_positions.sum { |profile, _position| profile.resource_unit_count }
      elsif profiles.any?
        positions.sum { |profile, _position| profile.resource_unit_count }
      else
        required_quantity(assumption.expected_persons, :missing_persons, "Expected persons are missing.")
      end
    when "nights"
      required_quantity(nights, :missing_billable_nights, "Expected billable nights are missing.")
    when "resource_nights"
      quantity_for(component, assumption, basis: "resource_units") *
        required_quantity(nights, :missing_billable_nights, "Expected billable nights are missing.")
    when "person_nights"
      quantity_for(component, assumption, basis: "persons") *
        required_quantity(nights, :missing_billable_nights, "Expected billable nights are missing.")
    when "occupancy_positions"
      require_profiles!(profiles)
      filtered_positions.sum { |profile, _position| profile.resource_unit_count }
    when "occupancy_position_nights"
      require_profiles!(profiles)
      filtered_positions.sum { |profile, _position| profile.resource_unit_count } *
        required_quantity(nights, :missing_billable_nights, "Expected billable nights are missing.")
    when "single_occupancy_units"
      require_profiles!(profiles)
      single_occupancy_units(profiles)
    when "single_occupancy_nights"
      require_profiles!(profiles)
      single_occupancy_units(profiles) *
        required_quantity(nights, :missing_billable_nights, "Expected billable nights are missing.")
    else
      raise MissingInput.new(:invalid_quantity_basis, "The quantity basis is invalid.")
    end
  end

  def single_occupancy_units(profiles)
    profiles.sum do |profile|
      Array(@positions_by_profile[profile.id]).size == 1 ? profile.resource_unit_count : 0
    end
  end

  def totals_for(results)
    charges = role_total(results, "supplier_charge")
    credits = role_total(results, "supplier_credit")
    commission = role_total(results, "expected_commission")
    supplier_cost = charges - credits
    Totals.new(
      supplier_charges_minor_units: charges,
      supplier_credits_minor_units: credits,
      forecast_supplier_cost_minor_units: supplier_cost,
      expected_commission_minor_units: commission,
      expected_net_cost_after_commission_minor_units: supplier_cost - commission
    )
  end

  def role_total(results, role)
    results.select { |result| result.economic_role == role }.sum(&:rounded_minor_units)
  end

  def sum_totals(totals)
    Totals.new(
      supplier_charges_minor_units: totals.sum(&:supplier_charges_minor_units),
      supplier_credits_minor_units: totals.sum(&:supplier_credits_minor_units),
      forecast_supplier_cost_minor_units: totals.sum(&:forecast_supplier_cost_minor_units),
      expected_commission_minor_units: totals.sum(&:expected_commission_minor_units),
      expected_net_cost_after_commission_minor_units: totals.sum(&:expected_net_cost_after_commission_minor_units)
    )
  end

  def context_warnings(arrangement, version, source)
    warnings = []
    item_definition = Array(@items_by_version[version.id]).find do |definition|
      definition.arrangement_item_id == source.arrangement_item_id
    end
    occurrence_definition = Array(@occurrences_by_version[version.id]).find do |definition|
      definition.service_occurrence_id == source.service_occurrence_id &&
        definition.arrangement_item_id == source.arrangement_item_id
    end
    resource_definition = Array(@resources_by_version[version.id]).find do |definition|
      definition.supplier_resource_id == source.supplier_resource_id &&
        definition.arrangement_item_id == source.arrangement_item_id
    end
    warnings << warning(:invalid_item_context, "The source Item is not retained in this version.") if source.arrangement_item_id && !item_definition
    warnings << warning(:invalid_occurrence_context, "The source Occurrence is not retained in this version.") if source.service_occurrence_id && !occurrence_definition
    warnings << warning(:invalid_resource_context, "The source Resource is not retained in this version.") if source.supplier_resource_id && !resource_definition

    supplier = @suppliers_by_id[source.charging_supplier_id]
    warnings << warning(:missing_charging_supplier, "The charging Supplier is unavailable.") unless supplier
    warnings << warning(:inactive_charging_supplier, "The charging Supplier is inactive.") if supplier&.inactive?
    eligible_ids = [ arrangement.contracting_supplier_id ]
    eligible_ids << item_definition&.default_service_provider_id if source.arrangement_item_id
    eligible_ids << occurrence_definition&.service_provider_id if source.service_occurrence_id
    if source.arrangement_wide?
      eligible = source.charging_supplier_id == arrangement.contracting_supplier_id
    else
      eligible = eligible_ids.compact.include?(source.charging_supplier_id)
    end
    warnings << warning(:ineligible_charging_supplier, "The charging Supplier is not eligible for this exact context.") unless eligible
    warnings
  end

  def source_result(source, definition, reason, complete, components, totals, warnings)
    SourceResult.new(
      source_id: source.id,
      label: source.label,
      context: {
        arrangement_item_id: source.arrangement_item_id,
        service_occurrence_id: source.service_occurrence_id,
        supplier_resource_id: source.supplier_resource_id
      },
      charging_supplier_id: source.charging_supplier_id,
      selected_stage: definition&.stage,
      selection_reason: reason,
      complete: complete,
      definition_id: definition&.id,
      currency: definition&.currency,
      components: components,
      totals: totals,
      zero_cost_reason: definition&.zero_cost_reason,
      warnings: warnings
    )
  end

  def components_base_record(component, base)
    return unless base
    Array(@components_by_definition[component.supplier_cost_definition_id]).find do |candidate|
      candidate.id == base.base_component_id
    end
  end

  def compatible_quantity_formula?(component, base)
    component.quantity_basis == base.quantity_basis &&
      component.participant_category_id == base.participant_category_id &&
      component.occupancy_position_from == base.occupancy_position_from &&
      component.occupancy_position_to == base.occupancy_position_to
  end

  def context_key(record)
    [
      record.supplier_arrangement_version_id,
      record.arrangement_item_id,
      record.service_occurrence_id,
      record.supplier_resource_id
    ]
  end

  def required_quantity(value, code, message)
    value.nil? ? raise(MissingInput.new(code, message)) : value
  end

  def require_profiles!(profiles)
    raise MissingInput.new(:missing_occupancy_profiles, "Occupancy profiles are missing.") if profiles.empty?
  end

  def round_minor_units(value)
    value.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def warning(code, message, **details)
    { code: code, message: message }.merge(details)
  end

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end

  class MissingInput < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
