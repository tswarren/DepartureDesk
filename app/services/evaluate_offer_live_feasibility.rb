# frozen_string_literal: true

class EvaluateOfferLiveFeasibility
  PathReason = Data.define(:binding_id, :label, :code, :message)
  Result = Data.define(:label, :reasons, :unused_alternative_reasons, :observed_at, :selected_binding_ids)

  def initialize(agency:, version:, scenario: {}, selected_inclusion_ids: [], package_version: nil)
    @agency = agency
    @version = version
    @package_version = package_version
    @scenario = EvaluateClientPrice::Scenario.build(scenario)
    @selected_inclusion_ids = Array(selected_inclusion_ids).map(&:to_s)
  end

  def call
    observed_at = Time.current

    if @package_version
      return unavailable("lifecycle", "That package version is not currently selectable.", observed_at) unless @package_version.published?
    elsif @version.retired? || @version.superseded? || !@version.published?
      return unavailable("lifecycle", "That version is not currently selectable.", observed_at)
    end

    sales_version = @package_version || @version
    sales = sales_version.sales_state
    if sales.nil? || !sales.sales_enabled
      return unavailable("sales_enabled", "Sales are paused for this version.", observed_at)
    end
    if sales_version.departure.departed?
      return unavailable("departure", "The Departure has departed.", observed_at)
    end

    if (window = sales_window_unavailable?(sales_version, observed_at))
      return window
    end
    if @package_version && (cap = cap_unavailable?(@package_version, "package", observed_at))
      return cap
    end
    if !@package_version && (cap = cap_unavailable?(@version, "service", observed_at))
      return cap
    end

    reasons = []
    on_request = false
    selected_bindings = []

    if @package_version
      selection = ValidatePackagePreviewSelections.new(
        package_version: @package_version,
        scenario: @scenario,
        selected_inclusion_ids: @selected_inclusion_ids
      ).call
      return unavailable("choices", selection.message, observed_at) unless selection.ok

      selected_service_versions(@package_version).each do |sov|
        if sov.definition && !sov.definition.m3_backed?
          on_request = true
          reasons << PathReason.new(
            binding_id: nil, label: "on_request", code: "fulfillment",
            message: "Fulfillment is on request or Agency/external."
          )
          next
        end

        collected = CollectSelectedOfferBindings.new(version: sov, scenario: @scenario, package_preview: true).call
        unless collected.status == :ok
          return unavailable("source", collected.reason, observed_at)
        end
        selected_bindings.concat(collected.bindings)
      end
    else
      if @version.definition && !@version.definition.m3_backed?
        return Result.new(
          label: "on_request",
          reasons: [
            PathReason.new(
              binding_id: nil, label: "on_request", code: "fulfillment",
              message: "Fulfillment is on request or Agency/external."
            )
          ],
          unused_alternative_reasons: [],
          observed_at: observed_at,
          selected_binding_ids: []
        )
      end

      collected = CollectSelectedOfferBindings.new(version: @version, scenario: @scenario).call
      unless collected.status == :ok
        return unavailable("source", collected.reason, observed_at)
      end
      selected_bindings = collected.bindings
    end

    selected_bindings.uniq.each do |binding|
      path = evaluate_binding(binding)
      if path[:label] == "unavailable"
        reasons << PathReason.new(binding_id: binding.id, label: "unavailable", code: path[:code], message: path[:message])
      elsif path[:label] == "on_request"
        on_request = true
        reasons << PathReason.new(binding_id: binding.id, label: "on_request", code: path[:code], message: path[:message])
      end
    end

    if reasons.any? { |row| row.label == "unavailable" }
      return Result.new(
        label: "unavailable", reasons: reasons, unused_alternative_reasons: [],
        observed_at: observed_at, selected_binding_ids: selected_bindings.map(&:id)
      )
    end

    Result.new(
      label: on_request ? "on_request" : "selectable_now",
      reasons: reasons.uniq { |row| [ row.code, row.message ] },
      unused_alternative_reasons: [],
      observed_at: observed_at,
      selected_binding_ids: selected_bindings.map(&:id)
    )
  end

  private

  def selected_service_versions(package_version)
    inclusions = package_version.inclusions.includes(:service_offer_version).order(:position).to_a
    inclusions.select { |row|
      row.included? || @selected_inclusion_ids.include?(row.id.to_s)
    }.map(&:service_offer_version)
  end

  def unavailable(code, message, observed_at)
    Result.new(
      label: "unavailable",
      reasons: [ PathReason.new(binding_id: nil, label: "unavailable", code: code, message: message) ],
      unused_alternative_reasons: [],
      observed_at: observed_at,
      selected_binding_ids: []
    )
  end

  def sales_window_unavailable?(version, observed_at)
    return unless version.respond_to?(:sales_starts_on)
    return if version.sales_starts_on.blank?

    zone = ActiveSupport::TimeZone[version.departure.time_zone] || ActiveSupport::TimeZone["UTC"]
    local_date = observed_at.in_time_zone(zone).to_date
    if local_date < version.sales_starts_on || local_date > version.sales_ends_on
      return unavailable("sales_window", "Outside the local sales window.", observed_at)
    end

    nil
  end

  def cap_unavailable?(version, kind, observed_at)
    return unless version.respond_to?(:sales_cap_quantity)
    return if version.sales_cap_quantity.blank?

    quantity = case version.sales_cap_basis
    when "persons" then @scenario.persons
    when "resource_units" then @scenario.resource_units
    when "package_bookings" then 1
    else
      return unavailable("cap", "Unsupported sales cap basis.", observed_at)
    end
    if quantity.nil? || quantity == ""
      return unavailable("cap", "Enter the scenario quantity required for the #{kind} sales cap.", observed_at)
    end
    if Integer(quantity) > version.sales_cap_quantity
      return unavailable("cap", "Scenario quantity exceeds the configured #{kind} sales cap.", observed_at)
    end

    nil
  rescue ArgumentError, TypeError
    unavailable("cap", "Scenario quantity is invalid for the sales cap.", observed_at)
  end

  def evaluate_binding(binding)
    arrangement_version = binding.supplier_arrangement_version
    unless arrangement_version&.activated?
      return { label: "unavailable", code: "source_lifecycle", message: "Bound source is not activated." }
    end

    arrangement = binding.supplier_arrangement
    if arrangement&.ended?
      return { label: "unavailable", code: "arrangement_ended", message: "The Arrangement has ended." }
    end

    supplier = arrangement&.contracting_supplier
    if supplier && !supplier.active?
      return { label: "unavailable", code: "supplier_inactive", message: "The bound Supplier is inactive." }
    end

    if binding.capacity_pool_id.present?
      pool = CapacityPool.find_by(id: binding.capacity_pool_id)
      if pool&.numeric_inventory?
        projection = CapacityProjection.find_by(capacity_pool_id: pool.id)
        qty = projection&.current_supplier_capacity
        if qty.nil?
          return { label: "unavailable", code: "capacity_unknown", message: "Numeric Pool projection is unknown." }
        end
        needed = begin
          Integer(@scenario.resource_units.presence || @scenario.persons.presence || 1)
        rescue ArgumentError, TypeError
          1
        end
        if qty < needed
          return { label: "unavailable", code: "capacity_shortage", message: "Numeric Pool capacity is short for this scenario." }
        end
      else
        return { label: "on_request", code: "nonnumeric_pool", message: "Supply is on request or externally managed." }
      end
    end

    definition = binding.service_offer_version.definition
    if definition && !definition.m3_backed?
      return { label: "on_request", code: "fulfillment", message: "Fulfillment is on request or Agency/external." }
    end

    { label: "selectable_now", code: "ok", message: "Path is selectable now." }
  end
end
