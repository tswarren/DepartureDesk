# frozen_string_literal: true

class CompileTransportationAgreement
  Segment = Data.define(
    :item, :item_definition, :occurrence_definition, :resource_definition,
    :pool_definition, :component, :deadline, :confirmed_units, :controlled_units,
    :remaining_on_request, :passenger_spaces, :maximum_passengers,
    :rate_minor_units, :exposure_minor_units, :advanced_reason
  )
  Clarification = Data.define(:code, :message)
  Result = Data.define(
    :arrangement, :version, :segments, :amount_due, :exposure_minor_units,
    :clarifications, :confirmation_allowed, :confirmation_blocker,
    :activation_allowed, :activation_blocker, :confirmed, :editable
  )

  def initialize(agency:, departure:, arrangement:, version:)
    @agency = agency
    @departure = departure
    @arrangement = arrangement
    @version = version
  end

  def call
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version
    ).call
    segments = item_definitions.map { |definition| build_segment(definition, forecast) }
    amount_due = EvaluateSupplierAmountDue.new(version: @version).call
    clarifications = clarifications_for(segments, amount_due)
    confirmation_blocker = confirmation_blocker_for(segments)
    activation_blocker = activation_blocker_for(segments, confirmation_blocker)
    Result.new(
      arrangement: @arrangement,
      version: @version,
      segments:,
      amount_due:,
      exposure_minor_units: segments.sum { |segment| segment.exposure_minor_units.to_i },
      clarifications:,
      confirmation_allowed: confirmation_blocker.nil?,
      confirmation_blocker:,
      activation_allowed: activation_blocker.nil?,
      activation_blocker:,
      confirmed: SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id),
      editable: @version.draft? && !SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)
    )
  end

  private

  def item_definitions
    @version.arrangement_item_definitions.where(category: "ground_transportation").order(:position, :id).to_a
  end

  def build_segment(item_definition, forecast)
    item = item_definition.arrangement_item
    occurrence_definition = @version.service_occurrence_definitions.where(arrangement_item: item).order(:id).first
    resource_definition = @version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id).first
    pool_definition = @version.capacity_pool_definitions.find_by(arrangement_item: item)
    component = coach_component(item)
    deadline = deadline_for(item)
    pool = pool_definition&.capacity_pool
    controlled = controlled_units(pool_definition, pool)
    confirmed = pool ? BillableCapacityQuantity.confirmed_for_ceiling(pool:, version: @version) : controlled
    occupancy = resource_definition&.maximum_occupancy.to_i
    ceiling = pool_definition&.maximum_total_resource_units
    source = matching_source(forecast, item)
    exposure = source&.totals&.forecast_supplier_cost_minor_units
    Segment.new(
      item:,
      item_definition:,
      occurrence_definition:,
      resource_definition:,
      pool_definition:,
      component:,
      deadline:,
      confirmed_units: confirmed,
      controlled_units: controlled,
      remaining_on_request: ceiling ? [ ceiling - confirmed, 0 ].max : nil,
      passenger_spaces: controlled * occupancy,
      maximum_passengers: ceiling ? ceiling * occupancy : nil,
      rate_minor_units: component&.amount_minor_units,
      exposure_minor_units: exposure,
      advanced_reason: advanced_reason(item, occurrence_definition, resource_definition, pool_definition, component)
    )
  end

  def matching_source(forecast, item)
    forecast.arrangements.flat_map(&:sources).find do |entry|
      source = SupplierCostSource.find_by(id: entry.source_id)
      source&.arrangement_item_id == item.id
    end
  end

  def controlled_units(pool_definition, pool)
    return 0 if pool_definition.nil?
    return pool_definition.proposed_opening_quantity.to_i if @version.draft? || pool&.capacity_projection.nil?

    pool.capacity_projection.current_supplier_capacity.to_i
  end

  def advanced_reason(item, occurrence_definition, resource_definition, pool_definition, component)
    return "Add one segment occurrence." if @version.service_occurrence_definitions.where(arrangement_item: item).count != 1
    return "Add one motorcoach." if @version.supplier_resource_definitions.where(arrangement_item: item).count != 1
    return "Enter a pickup and drop-off." if occurrence_definition.origin_name.blank? || occurrence_definition.destination_name.blank?
    return "Enter passenger capacity per motorcoach." if resource_definition.maximum_occupancy.blank?
    return "Add one motorcoach Pool." if pool_definition.nil? || pool_definition.capacity_pool.measurement_basis != "resource_units" || pool_definition.capacity_pool.inventory_mode != "block"
    return "Enter the on-request ceiling." if pool_definition.maximum_total_resource_units.blank?
    assumption = @version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    if assumption && (assumption.supplier_cost_occupancy_profiles.exists? || assumption.expected_persons.present? || assumption.expected_billable_nights.present?)
      return SaveTransportationSegment::ADVANCED
    end
    return nil if component.nil?

    return "The per-coach rate must be a contracted resource-unit charge." unless component.unit_rate? && component.resource_units? && component.supplier_charge? && component.supplier_cost_definition.contracted?
    return "Link the per-coach rate to the motorcoach Pool." if component.quantity_capacity_pool_id.blank?
    nil
  end

  def confirmation_blocker_for(segments)
    return "Add a transportation segment." if segments.empty?
    reason = segments.filter_map(&:advanced_reason).first
    return reason if reason
    return "Record the Supplier rate per motorcoach." if segments.any? { |segment| segment.component.nil? }
    nil
  end

  def activation_blocker_for(segments, confirmation_blocker)
    return confirmation_blocker if confirmation_blocker
    return "Confirm the Transportation agreement before activation." unless SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)
    if segments.any? { |segment| segment.component && !segment.component.supplier_cost_definition.forecast_ready? }
      return "Mark the per-coach rate ready before activation."
    end
    if segments.any? { |segment| segment.component&.supplier_cost_definition&.estimate? }
      return "An estimate cannot activate where the charter requires a contracted rate."
    end
    nil
  end

  def clarifications_for(segments, amount_due)
    notes = [ Clarification.new(code: "cancellation", message: "Cancellation terms — Needs clarification") ]
    return notes if amount_due.nil?

    pools = segments.filter_map { |segment| segment.pool_definition&.capacity_pool }
    late = pools.any? do |pool|
      pool.capacity_events.where(event_type: %w[established increased]).where("effective_on > ?", amount_due.due_on).exists?
    end
    released = pools.any? { |pool| pool.capacity_events.where(event_type: %w[released withdrawn]).exists? }
    notes << Clarification.new(code: "late_coach", message: "Payment treatment for a motorcoach confirmed after #{amount_due.due_on.strftime('%b %-d')} — Needs clarification") if late
    notes << Clarification.new(code: "release", message: "Financial effect of a released motorcoach — Needs clarification") if released
    notes
  end

  def coach_component(item)
    @version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
      .includes(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { arrangement_item_id: item.id }, calculation_kind: "unit_rate", quantity_basis: "resource_units")
      .order(:position).first
  end

  def deadline_for(item)
    @version.supplier_deadline_definitions.joins(:supplier_deadline_definition_coverage_links)
      .where(deadline_type: "final_count_due", supplier_deadline_definition_coverage_links: { arrangement_item_id: item.id })
      .first
  end
end
