# frozen_string_literal: true

class EvaluateClientPrice
  ComponentLine = Data.define(
    :definition_id, :component_id, :label, :position, :client_role, :calculation_kind,
    :quantity, :rate, :rounding_mode, :rounding_boundary, :percentage_treatment,
    :included, :signed_revenue_effect_minor_units, :formula
  )
  Result = Data.define(
    :complete, :amount_minor_units, :currency, :lines, :blockers, :observed_at, :kind
  )
  BundledPackage = Data.define(:base_price_minor_units, :currency, :single_occupancy_supplement_rate)
  NamedAdjustment = Data.define(:label, :amount_minor_units, :direction)
  ServiceSum = Data.define(:service_results, :adjustments)
  OccupancyPosition = Data.define(:key, :rate_category)
  Scenario = Data.define(
    :service_instances, :persons, :resource_units, :nights, :occupancy_positions,
    :selected_binding_ids, :selected_option_ids, :enrollment_denominator
  ) do
    def self.build(attrs = {})
      hash = attrs.to_h.with_indifferent_access
      positions_raw = hash[:occupancy_positions]
      position_list = if positions_raw.is_a?(Hash)
        positions_raw.sort_by { |key, _| key.to_i }.map(&:last)
      else
        Array(positions_raw)
      end
      positions = position_list.map do |position|
        next position if position.is_a?(OccupancyPosition)

        row = position.to_h.with_indifferent_access
        OccupancyPosition.new(
          key: row[:key].presence || row[:occupancy_position_key].presence,
          rate_category: row[:rate_category].presence || row[:client_rate_category_key].presence
        )
      end
      new(
        service_instances: integer_or_nil(hash[:service_instances]),
        persons: integer_or_nil(hash[:persons]),
        resource_units: integer_or_nil(hash[:resource_units]),
        nights: integer_or_nil(hash[:nights]),
        occupancy_positions: positions,
        selected_binding_ids: Array(hash[:selected_binding_ids]).compact,
        selected_option_ids: Array(hash[:selected_option_ids]).compact,
        enrollment_denominator: integer_or_nil(hash[:enrollment_denominator])
      )
    end

    def self.integer_or_nil(value)
      return if value.nil? || value == ""

      Integer(value)
    rescue ArgumentError, TypeError
      value
    end

    def resource_unit_count
      return 1 if resource_units.nil? || resource_units == ""

      Integer(resource_units)
    rescue ArgumentError, TypeError
      resource_units
    end

    def expanded_occupancy_pattern?
      return false if occupancy_positions.empty?

      occupancy_positions.count { |position| position.key == "first" } > 1 ||
        occupancy_positions.count { |position| position.key == "single" } > 1
    end

    def expanded_occupant_count
      occupancy_positions.size * Integer(resource_unit_count)
    end

    def persons_disagree_with_occupancy?
      return false if occupancy_positions.empty? || persons.nil? || persons == ""

      Integer(persons) != expanded_occupant_count
    rescue ArgumentError, TypeError
      true
    end
  end

  class MissingInput < StandardError
    attr_reader :code, :field

    def initialize(code, message, field: nil)
      @code = code
      @field = field
      super(message)
    end
  end

  def initialize(definition: nil, scenario: {}, bundled_package: nil, service_sum: nil, bundled_completeness: false)
    @definition = definition
    @scenario = scenario.is_a?(Scenario) ? scenario : Scenario.build(scenario)
    @bundled_package = bundled_package
    @service_sum = service_sum
    @bundled_completeness = bundled_completeness
    @observed_at = Time.current
  end

  def call
    return evaluate_bundled_package if @bundled_package
    return evaluate_service_sum if @service_sum
    return complete_unpriced_bundled_component if @definition.nil? && @bundled_completeness
    return incomplete("A Client price is required.", field: :price) if @definition.nil?

    cap = service_offer_cap_incomplete
    return cap if cap

    graph = normalize_graph(@definition)
    return evaluate_zero_price(graph) if graph[:mode] == "zero_price"
    return incomplete("A calculated price needs at least one component.", field: :components) if graph[:components].empty?
    return incomplete("A generic base price cannot overlap a more specific base price.", field: :base_price) if overlapping_bases?(graph)

    evaluate_graph(graph)
  rescue MissingInput => error
    incomplete(error.message, field: error.field, code: error.code)
  end

  private

  def evaluate_zero_price(graph)
    Result.new(
      complete: true,
      amount_minor_units: 0,
      currency: graph[:currency],
      lines: [],
      blockers: [],
      observed_at: @observed_at,
      kind: :service
    )
  end

  def complete_unpriced_bundled_component
    Result.new(
      complete: true,
      amount_minor_units: 0,
      currency: nil,
      lines: [],
      blockers: [],
      observed_at: @observed_at,
      kind: :bundled_component
    )
  end

  def service_offer_cap_incomplete
    version = @definition.service_offer_version if @definition.respond_to?(:service_offer_version)
    return if version.nil? || version.sales_cap_quantity.blank?

    quantity = case version.sales_cap_basis
    when "persons" then @scenario.persons
    when "resource_units" then @scenario.resource_units
    end
    return if quantity.nil? || quantity <= version.sales_cap_quantity

    incomplete("This example exceeds the service sales cap.", field: :sales_cap)
  end

  def evaluate_bundled_package
    package = @bundled_package
    persons = required_quantity(@scenario.persons, :persons, "Enter the number of persons.")
    currency = package.currency
    base = Integer(package.base_price_minor_units)
    lines = []
    amount = case persons
    when 2
      lines << package_line("Double occupancy", 2 * base, currency, quantity: 2)
      2 * base
    when 1
      lines << package_line("Single occupancy base", base, currency, quantity: 1)
      if package.single_occupancy_supplement_rate.nil?
        base
      else
        supplement_rate = BigDecimal(package.single_occupancy_supplement_rate.to_s)
        supplement = round_minor_units(BigDecimal(base.to_s) * supplement_rate)
        lines << package_line("Single occupancy supplement", supplement, currency, quantity: 1, rate: supplement_rate)
        base + supplement
      end
    else
      return incomplete("Bundled occupancy preview supports one or two travelers.", field: :persons)
    end

    Result.new(
      complete: true,
      amount_minor_units: amount,
      currency: currency,
      lines: lines,
      blockers: [],
      observed_at: @observed_at,
      kind: :bundled_package
    )
  end

  def evaluate_service_sum
    results = Array(@service_sum.service_results)
    incomplete_result = results.find { |result| !result.complete }
    return incomplete_result if incomplete_result

    amount = results.sum { |result| result.amount_minor_units.to_i }
    currency = results.filter_map(&:currency).uniq
    return incomplete("Service-sum prices must share one currency.", field: :currency) if currency.size > 1

    adjustment_lines = []
    Array(@service_sum.adjustments).each_with_index do |adjustment, index|
      signed = adjustment.direction.to_s == "subtract" ? -adjustment.amount_minor_units.to_i : adjustment.amount_minor_units.to_i
      amount += signed
      adjustment_lines << ComponentLine.new(
        definition_id: nil,
        component_id: nil,
        label: adjustment.label,
        position: 10_000 + index,
        client_role: adjustment.direction.to_s == "subtract" ? "named_discount" : "named_surcharge",
        calculation_kind: "fixed",
        quantity: 1,
        rate: nil,
        rounding_mode: "half_up",
        rounding_boundary: "currency_minor_unit",
        percentage_treatment: nil,
        included: false,
        signed_revenue_effect_minor_units: signed,
        formula: { amount_minor_units: adjustment.amount_minor_units, evaluated_quantity: 1 }
      )
    end

    Result.new(
      complete: true,
      amount_minor_units: amount,
      currency: currency.first,
      lines: results.flat_map(&:lines) + adjustment_lines,
      blockers: [],
      observed_at: @observed_at,
      kind: :service_sum
    )
  end

  def evaluate_graph(graph)
    validate_occupancy_fit!
    lines = []
    by_id = {}
    total = 0

    graph[:components].sort_by { |component| [ component[:position], component[:id].to_s ] }.each do |component|
      next unless component_applies?(component)

      line = evaluate_component(graph, component, by_id)
      lines << line
      by_id[component[:id]] = line
      total += line.signed_revenue_effect_minor_units
    end

    if graph[:components].none? { |component| component[:client_role] == "base_price" && component_applies?(component) }
      return incomplete("A usable base price is missing for this scenario.", field: :base_price)
    end

    Result.new(
      complete: true,
      amount_minor_units: total,
      currency: graph[:currency],
      lines: lines,
      blockers: [],
      observed_at: @observed_at,
      kind: :service
    )
  end

  def evaluate_component(graph, component, earlier)
    quantity = nil
    bases = Array(component[:bases]).sort_by { |base| [ base[:position].to_i, base[:base_component_id].to_s ] }
    if component[:calculation_kind] == "percentage" && bases.empty?
      raise MissingInput.new(:missing_percentage_base, "A percentage component must name at least one earlier base.", field: :bases)
    end

    base_links = bases.map do |base|
      earlier_line = earlier[base[:base_component_id]] ||
        raise(MissingInput.new(:invalid_component_base, "A percentage base is missing or is not earlier.", field: :bases))
      if earlier_line.included
        raise MissingInput.new(:included_tax_base, "An included-tax allocation cannot be a later percentage base.", field: :bases)
      end

      {
        base_component_id: base[:base_component_id],
        direction: base[:direction],
        signed_revenue_effect_minor_units: earlier_line.signed_revenue_effect_minor_units
      }
    end
    monetary_base = base_links.sum do |base|
      base[:direction] == "subtract" ? -base[:signed_revenue_effect_minor_units] : base[:signed_revenue_effect_minor_units]
    end

    unrounded, formula = case component[:calculation_kind]
    when "fixed"
      quantity = quantity_for("service_instances")
      [
        BigDecimal(component[:amount_minor_units].to_s) * quantity,
        { amount_minor_units: component[:amount_minor_units], evaluated_quantity: quantity }
      ]
    when "unit_rate"
      quantity = quantity_for(component[:quantity_basis], component: component)
      [
        BigDecimal(component[:amount_minor_units].to_s) * quantity,
        { unit_rate_minor_units: component[:amount_minor_units], evaluated_quantity: quantity }
      ]
    when "percentage"
      if monetary_base.negative?
        raise MissingInput.new(:invalid_percentage_base, "A percentage base cannot be negative.", field: :bases)
      end
      rate = BigDecimal(component[:rate].to_s)
      value = BigDecimal(monetary_base.to_s) * rate
      value /= (BigDecimal("1") + rate) if component[:percentage_treatment] == "included"
      [
        value,
        {
          monetary_base_minor_units: monetary_base,
          rate: rate.to_s("F"),
          treatment: component[:percentage_treatment]
        }
      ]
    else
      raise MissingInput.new(:unsupported_calculation_kind, "The calculation kind is not supported.", field: :calculation_kind)
    end

    rounded = round_minor_units(unrounded)
    included = component[:client_role] == "tax_fee" && component[:percentage_treatment] == "included"
    direction = if included
      0
    elsif component[:client_role] == "named_discount"
      -1
    else
      1
    end

    ComponentLine.new(
      definition_id: graph[:id],
      component_id: component[:id],
      label: component[:label],
      position: component[:position],
      client_role: component[:client_role],
      calculation_kind: component[:calculation_kind],
      quantity: quantity,
      rate: component[:rate]&.then { |rate| BigDecimal(rate.to_s).to_s("F") },
      rounding_mode: "half_up",
      rounding_boundary: "currency_minor_unit",
      percentage_treatment: component[:percentage_treatment],
      included: included,
      signed_revenue_effect_minor_units: rounded * direction,
      formula: formula.merge(unrounded_minor_units: unrounded.to_s("F"), rounded_minor_units: rounded)
    )
  end

  def component_applies?(component)
    positions = matching_positions(component)
    return false if occupancy_selector?(component) && positions.empty?
    return false if category_selector?(component) && !category_applies?(component)

    true
  end

  def occupancy_selector?(component)
    component[:occupancy_position_key].present?
  end

  def category_selector?(component)
    component[:client_rate_category_key].present?
  end

  def category_applies?(component)
    wanted = component[:client_rate_category_key]
    return true if wanted.blank?

    scenario_categories = @scenario.occupancy_positions.map(&:rate_category).compact
    scenario_categories.any? { |category| category == wanted }
  end

  def matching_positions(component)
    positions = @scenario.occupancy_positions
    return positions if component.nil?

    positions.select do |position|
      occupancy_ok = component[:occupancy_position_key].blank? || position.key == component[:occupancy_position_key]
      category_ok = component[:client_rate_category_key].blank? || position.rate_category == component[:client_rate_category_key]
      occupancy_ok && category_ok
    end
  end

  def selector?(component)
    occupancy_selector?(component) || category_selector?(component)
  end

  def matching_quantity(component)
    positions = matching_positions(component)
    if positions.empty?
      raise MissingInput.new(:missing_occupancy_positions, "Enter occupancy positions.", field: :occupancy_positions)
    end

    positions.size * resource_unit_count
  end

  def resource_unit_count
    count = @scenario.resource_unit_count
    integer = Integer(count)
    raise MissingInput.new(:invalid_resource_units, "Enter a valid resource count.", field: :resource_units) if integer <= 0

    integer
  rescue ArgumentError, TypeError
    raise MissingInput.new(:invalid_resource_units, "Enter a valid resource count.", field: :resource_units)
  end

  def quantity_for(basis, component: nil)
    case basis
    when "service_instances"
      required_quantity(@scenario.service_instances || 1, :service_instances, "Enter the selected service quantity.")
    when "persons"
      if component && selector?(component)
        matching_quantity(component)
      else
        required_quantity(@scenario.persons, :persons, "Enter the number of persons.")
      end
    when "resource_units"
      required_quantity(@scenario.resource_units, :resource_units, "Enter the resource count.")
    when "nights"
      required_quantity(@scenario.nights, :nights, "Enter billable nights.")
    when "person_nights"
      quantity_for("persons", component: component) * quantity_for("nights")
    when "resource_nights"
      quantity_for("resource_units") * quantity_for("nights")
    when "occupancy_positions"
      matching_quantity(component)
    when "occupancy_position_nights"
      quantity_for("occupancy_positions", component: component) * quantity_for("nights")
    else
      raise MissingInput.new(:invalid_quantity_basis, "The quantity basis is invalid.", field: :quantity_basis)
    end
  end

  def required_quantity(value, field, message)
    integer = Integer(value)
    raise MissingInput.new(:"missing_#{field}", message, field: field) if integer <= 0

    integer
  rescue ArgumentError, TypeError
    raise MissingInput.new(:"missing_#{field}", message, field: field)
  end

  def validate_occupancy_fit!
    return if @scenario.occupancy_positions.empty?

    resource_unit_count
    if @scenario.expanded_occupancy_pattern?
      raise MissingInput.new(
        :expanded_occupancy_pattern,
        "Occupancy positions describe one resource, not every cabin.",
        field: :occupancy_positions
      )
    end
    if @scenario.persons_disagree_with_occupancy?
      raise MissingInput.new(
        :persons_occupancy_mismatch,
        "Persons must equal occupancy positions times the resource count.",
        field: :persons
      )
    end
  end

  def overlapping_bases?(graph)
    bases = graph[:components].select { |component| component[:client_role] == "base_price" }
    bases.combination(2).any? do |left, right|
      selector_overlap?(left[:client_rate_category_key], right[:client_rate_category_key]) &&
        selector_overlap?(left[:occupancy_position_key], right[:occupancy_position_key])
    end
  end

  def selector_overlap?(left, right)
    left.blank? || right.blank? || left == right
  end

  def normalize_graph(definition)
    if definition.is_a?(ServiceOfferPriceDefinition)
      components = definition.service_offer_price_components.sort_by { |component| [ component.position, component.id ] }
      {
        id: definition.id,
        currency: definition.currency,
        mode: definition.mode,
        components: components.map { |component| component_hash_from_record(component) }
      }
    else
      hash = definition.to_h.with_indifferent_access
      {
        id: hash[:id],
        currency: hash[:currency],
        mode: hash[:mode].presence || "calculated",
        components: Array(hash[:components]).map { |component| component_hash_from_dto(component) }
      }
    end
  end

  def component_hash_from_record(component)
    {
      id: component.id,
      label: component.label,
      client_role: component.client_role,
      calculation_kind: component.calculation_kind,
      amount_minor_units: component.amount_minor_units,
      rate: component.rate,
      quantity_basis: component.quantity_basis,
      percentage_treatment: component.percentage_treatment,
      client_rate_category_key: component.client_rate_category_key,
      occupancy_position_key: component.occupancy_position_key,
      position: component.position,
      bases: component.service_offer_price_component_bases.sort_by { |base| [ base.position, base.id ] }.map do |base|
        { base_component_id: base.base_component_id, direction: base.direction, position: base.position }
      end
    }
  end

  def component_hash_from_dto(component)
    hash = component.to_h.with_indifferent_access
    {
      id: hash[:id] || "component-#{hash[:position]}",
      label: hash[:label],
      client_role: hash[:client_role],
      calculation_kind: hash[:calculation_kind],
      amount_minor_units: hash[:amount_minor_units],
      rate: hash[:rate],
      quantity_basis: hash[:quantity_basis],
      percentage_treatment: hash[:percentage_treatment],
      client_rate_category_key: hash[:client_rate_category_key],
      occupancy_position_key: hash[:occupancy_position_key],
      position: hash[:position],
      bases: Array(hash[:bases]).map.with_index(1) do |base, index|
        row = base.to_h.with_indifferent_access
        {
          base_component_id: row[:base_component_id] || row[:base_position] || row[:position],
          direction: row[:direction].presence || "add",
          position: row[:position] || index
        }
      end
    }
  end

  def package_line(label, amount, currency, quantity:, rate: nil)
    ComponentLine.new(
      definition_id: nil,
      component_id: nil,
      label: label,
      position: 0,
      client_role: "base_price",
      calculation_kind: rate ? "percentage" : "fixed",
      quantity: quantity,
      rate: rate&.to_s("F"),
      rounding_mode: "half_up",
      rounding_boundary: "currency_minor_unit",
      percentage_treatment: nil,
      included: false,
      signed_revenue_effect_minor_units: amount,
      formula: { currency: currency, rounded_minor_units: amount }
    )
  end

  def round_minor_units(value)
    value.round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def incomplete(message, field: nil, code: :incomplete)
    Result.new(
      complete: false,
      amount_minor_units: nil,
      currency: currency_from_definition,
      lines: [],
      blockers: [ { message: message, field: field, code: code } ],
      observed_at: @observed_at,
      kind: :service
    )
  end

  def currency_from_definition
    return @bundled_package.currency if @bundled_package
    return @definition.currency if @definition.respond_to?(:currency)

    @definition.to_h.with_indifferent_access[:currency] if @definition.respond_to?(:to_h)
  rescue StandardError
    nil
  end
end
