module CapacityActivatedGraphHelper
  def build_activated_unestablished_capacity_graph(
    agency: @agency,
    departure: @departure,
    contractor: @contractor,
    provider: @provider,
    actor: @actor,
    prefix: "Activated Capacity",
    quantity: 8,
    inventory_mode: "block",
    measurement_basis: "resource_units",
    unit_label: "cabins",
    evidence_kind: "contract",
    evidence_on: Date.new(2026, 5, 1),
    evidence_reference_note: "Contracted capacity"
  )
    if departure.draft?
      departure.update!(
        status: "active",
        departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
        first_activated_at: Time.current
      )
    end
    graph = create_capacity_graph(
      agency: agency,
      departure: departure,
      contractor: contractor,
      provider: provider,
      prefix: prefix
    )
    pair = classify_capacity_graph_pair(graph)
    pool = CapacityPool.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: provider,
      inventory_mode: inventory_mode,
      measurement_basis: measurement_basis,
      effective_time_zone: graph[:occurrence_definition].time_zone
    )
    definition = CapacityPoolDefinition.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair,
      capacity_pool: pool,
      label: "#{prefix} pool",
      normalized_label: "#{prefix} pool".downcase,
      unit_label: unit_label,
      proposed_opening_quantity: pool.numeric_inventory? ? quantity : nil,
      evidence_kind: evidence_kind,
      evidence_on: evidence_on,
      evidence_reference_note: evidence_reference_note,
      override: false,
      position: 1
    )
    graph[:arrangement].update!(status: "active")
    graph[:version].update!(status: "activated")
    graph.merge(pair: pair, pool: pool, pool_definition: definition, actor: actor)
  end

  def build_activated_established_capacity_graph(
    agency: @agency,
    departure: @departure,
    contractor: @contractor,
    provider: @provider,
    actor: @actor,
    prefix: "Established Capacity",
    quantity: 8,
    recorded_at: Time.zone.parse("2026-06-01 12:00:00 UTC")
  )
    graph = build_activated_unestablished_capacity_graph(
      agency: agency,
      departure: departure,
      contractor: contractor,
      provider: provider,
      actor: actor,
      prefix: prefix,
      quantity: quantity
    )
    event = CapacityEvent.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pool: graph[:pool],
      supplying_supplier: provider,
      event_type: "established",
      quantity: quantity,
      measurement_basis: graph[:pool].measurement_basis,
      effective_on: graph[:occurrence_definition].starts_on,
      effective_time_zone: graph[:pool].effective_time_zone,
      applies_at: recorded_at,
      effective_sequence: 1,
      recorded_at: recorded_at,
      evidence_kind: graph[:pool_definition].evidence_kind,
      evidence_on: graph[:pool_definition].evidence_on,
      evidence_reference_note: graph[:pool_definition].evidence_reference_note,
      actor: actor
    )
    projection = CapacityProjection.create!(
      agency: agency,
      departure: departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pool: graph[:pool],
      current_supplier_capacity: quantity,
      last_event: event,
      last_effective_on: event.effective_on,
      last_effective_sequence: event.effective_sequence,
      last_recorded_at: event.recorded_at,
      rebuilt_at: recorded_at
    )
    graph.merge(established_event: event, projection: projection)
  end
end
