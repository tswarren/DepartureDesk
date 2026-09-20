# frozen_string_literal: true

class EvaluateIndicativeScenarioEconomics
  Result = Data.define(
    :status, :label, :client_revenue_minor_units, :forecast_supplier_cost_minor_units,
    :expected_commission_minor_units, :indicative_margin_minor_units, :currency,
    :price, :attributed_source_ids, :reason, :observed_at
  )

  OCCUPANCY_KEY_INDEX = {
    "first" => 1,
    "second" => 2,
    "single" => 1
  }.freeze

  def initialize(agency:, actor:, offer:, version: nil, scenario: {}, price: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @version = version
    @scenario = scenario.is_a?(EvaluateClientPrice::Scenario) ? scenario : EvaluateClientPrice::Scenario.build(scenario)
    @price = price
  end

  def call
    ensure_actor!
    offer = @agency.service_offers.find_by(id: record_id(@offer))
    return unknown("That service offer was not found.") if offer.nil?

    version = resolve_version(offer)
    return unknown("That service offer has no draft version.") if version.nil?

    price = @price || EvaluateClientPrice.new(
      definition: version.price_definition,
      scenario: @scenario
    ).call
    occupancy_blocker = occupancy_unknown_reason
    return unknown(occupancy_blocker, price: price) if occupancy_blocker
    return unknown("Client revenue is incomplete.", price: price) unless price.complete
    if price.currency.present? && offer.departure.operating_currency.present? &&
        price.currency != offer.departure.operating_currency
      return unknown("Client price currency does not match the departure.", price: price)
    end

    attributed = attribute_sources(version)
    return attributed if attributed.is_a?(Result)
    return unknown("No attributable Supplier cost source.", price: price) if attributed.empty?
    if attributed.any? { |source| selected_stage_category_scoped?(source) }
      return unknown("Supplier participant-category costs cannot be priced from this scenario.", price: price)
    end

    usage, occupancy = ephemeral_usage
    source_results = attributed.group_by { |source|
      [ source.supplier_arrangement_id, source.supplier_arrangement_version_id ]
    }.flat_map do |_key, rows|
      EvaluateSupplierCostForecast.new(
        agency: @agency,
        departure: offer.departure,
        arrangement: rows.first.supplier_arrangement,
        version: rows.first.supplier_arrangement_version
      ).call_attributed_sources(
        sources: rows,
        usage: usage,
        profiles: occupancy[:profiles],
        positions_by_profile: occupancy[:positions_by_profile]
      )
    end

    if source_results.size != attributed.size || source_results.any? { |result| !result.complete }
      return unknown("Attributed Supplier cost is incomplete or ambiguous.", price: price)
    end
    if source_results.map(&:currency).uniq != [ price.currency.presence || offer.departure.operating_currency ]
      return unknown("Supplier cost currency does not match the Client price.", price: price)
    end

    shared_ids = attributed.select { |source| shared_fixed_source?(source) }.map(&:id)
    if shared_ids.any? && @scenario.enrollment_denominator.blank?
      return unknown("Shared Arrangement cost needs an enrollment denominator.", price: price)
    end

    cost_total = 0
    commission_total = 0
    source_results.each do |result|
      cost = result.totals.forecast_supplier_cost_minor_units
      commission = result.totals.expected_commission_minor_units
      if shared_ids.include?(result.source_id)
        cost = allocate_shared(cost)
        commission = allocate_shared(commission)
      end
      cost_total += cost
      commission_total += commission
    end

    margin = price.amount_minor_units.to_i + commission_total - cost_total
    Result.new(
      status: :known,
      label: shared_ids.any? ? "scenario economics" : "indicative scenario economics",
      client_revenue_minor_units: price.amount_minor_units,
      forecast_supplier_cost_minor_units: cost_total,
      expected_commission_minor_units: commission_total,
      indicative_margin_minor_units: margin,
      currency: price.currency,
      price: price,
      attributed_source_ids: attributed.map(&:id),
      reason: nil,
      observed_at: Time.current
    )
  end

  private

  def ensure_actor!
    return if @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:manage_departures)

    raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
  end

  def resolve_version(offer)
    requested = @version
    if requested
      offer.versions.find_by(id: record_id(requested))
    else
      offer.editable_draft_version
    end
  end

  def attribute_sources(version)
    bindings = selected_bindings(version)
    return unknown("Choose exactly one alternative source for this scenario.") if bindings == :missing_alternative
    return unknown("An alternative group can select only one source.") if bindings == :ambiguous_alternative
    return unknown("A selected source is not part of this service offer.") if bindings == :unknown_selection
    return unknown("No attributable Supplier cost source.") if bindings.empty?

    sources = []
    bindings.each do |binding|
      matches = matching_sources(binding)
      return unknown("A required source has no attributable Supplier cost.") if matches.empty?
      exact_groups = matches.group_by { |source|
        [ source.arrangement_item_id, source.service_occurrence_id, source.supplier_resource_id ]
      }
      exact_groups.each_value do |group|
        if group.size > 1 && group.map { |source| [ source.arrangement_item_id, source.service_occurrence_id, source.supplier_resource_id ] }.uniq.size == 1
          # Complementary sources on the same pin are kept; identical duplicate rows are ambiguous.
          identities = group.map(&:id)
          sources.concat(group.uniq(&:id))
          next
        end

        sources.concat(group)
      end
    end

    sources.uniq(&:id)
  end

  def selected_bindings(version)
    bindings = version.source_bindings.to_a
    required = bindings.select(&:required?)
    grouped = bindings.select(&:alternative?).group_by(&:alternative_group_key)
    selected_ids = @scenario.selected_binding_ids.map(&:to_s).uniq
    offer_ids = bindings.map { |binding| binding.id.to_s }
    return :unknown_selection if selected_ids.any? { |id| offer_ids.exclude?(id) }

    chosen = grouped.flat_map do |_key, members|
      picked = members.select { |binding| selected_ids.include?(binding.id.to_s) }
      return :missing_alternative if picked.empty?
      return :ambiguous_alternative if picked.size > 1

      picked
    end

    required + chosen
  end

  def matching_sources(binding)
    scope = SupplierCostSource.where(
      agency_id: @agency.id,
      supplier_arrangement_version_id: binding.supplier_arrangement_version_id,
      arrangement_item_id: binding.arrangement_item_id
    ).includes(supplier_cost_definitions: :supplier_cost_components)
    if binding.item_only?
      scope = scope.where(service_occurrence_id: nil, supplier_resource_id: nil)
    else
      if binding.service_occurrence_id.blank?
        scope = scope.where(service_occurrence_id: nil)
      end
      if binding.supplier_resource_id.blank?
        scope = scope.where(supplier_resource_id: nil)
      end
    end
    scope.select { |source| source_matches_binding?(source, binding) }
  end

  def source_matches_binding?(source, binding)
    return false if binding.item_only? && (source.service_occurrence_id.present? || source.supplier_resource_id.present?)
    if source.service_occurrence_id.present?
      return false if source.service_occurrence_id != binding.service_occurrence_id
    end
    if source.supplier_resource_id.present?
      return false if source.supplier_resource_id != binding.supplier_resource_id
    end

    true
  end

  def shared_fixed_source?(source)
    return true if source.arrangement_wide?
    return false if source.service_occurrence_id.present? || source.supplier_resource_id.present?

    definition = source.supplier_cost_definitions.find { |row| row.forecast_ready? && (row.contracted? || row.estimate?) }
    return false if definition.nil?

    definition.supplier_cost_components.any? { |component|
      component.fixed? && component.supplier_charge?
    }
  end

  def occupancy_unknown_reason
    return if @scenario.occupancy_positions.empty?

    begin
      count = Integer(@scenario.resource_unit_count)
      return "Enter a valid resource count." if count <= 0
    rescue ArgumentError, TypeError
      return "Enter a valid resource count."
    end
    return "Occupancy positions describe one resource, not every cabin." if @scenario.expanded_occupancy_pattern?
    return "Persons must equal occupancy positions times the resource count." if @scenario.persons_disagree_with_occupancy?

    nil
  end

  def selected_forecast_definition(source)
    definitions = source.supplier_cost_definitions
    contracted = definitions.find { |definition| definition.contracted? && definition.forecast_ready? }
    estimate = definitions.find { |definition| definition.estimate? && definition.forecast_ready? }
    contracted || estimate
  end

  def selected_stage_category_scoped?(source)
    definition = selected_forecast_definition(source)
    return false if definition.nil?

    definition.supplier_cost_components.any? { |component| component.participant_category_id.present? }
  end

  def ephemeral_usage
    usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
      id: SecureRandom.uuid,
      expected_persons: @scenario.persons,
      expected_resource_units: @scenario.resource_units,
      expected_billable_nights: @scenario.nights
    )
    profile_id = SecureRandom.uuid
    positions = synthesized_positions(profile_id)
    profiles = if positions.any?
      [ EvaluateSupplierCostForecast::PreviewProfile.new(
        id: profile_id,
        resource_unit_count: Integer(@scenario.resource_unit_count)
      ) ]
    else
      []
    end

    [ usage, { profiles: profiles, positions_by_profile: { profile_id => positions } } ]
  end

  def synthesized_positions(profile_id)
    additional_index = 3
    @scenario.occupancy_positions.filter_map.with_index(1) do |position, index|
      number = case position.key
      when "additional"
        value = additional_index
        additional_index += 1
        value
      else
        OCCUPANCY_KEY_INDEX[position.key] || index
      end
      EvaluateSupplierCostForecast::EphemeralPosition.new(
        id: "#{profile_id}-#{index}",
        occupancy_position: number,
        participant_category_id: nil
      )
    end
  end

  def allocate_shared(amount)
    persons = @scenario.persons.presence || @scenario.service_instances.presence || 1
    enrollment = Integer(@scenario.enrollment_denominator)
    return 0 if enrollment <= 0

    (
      BigDecimal(amount.to_s) * BigDecimal(persons.to_s) / BigDecimal(enrollment.to_s)
    ).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def unknown(reason, price: nil)
    Result.new(
      status: :unknown,
      label: "indicative scenario economics",
      client_revenue_minor_units: price&.amount_minor_units,
      forecast_supplier_cost_minor_units: nil,
      expected_commission_minor_units: nil,
      indicative_margin_minor_units: nil,
      currency: price&.currency,
      price: price,
      attributed_source_ids: [],
      reason: reason,
      observed_at: Time.current
    )
  end

  def record_id(record)
    record.respond_to?(:id) ? record.id : record
  end
end
