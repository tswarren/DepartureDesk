# frozen_string_literal: true

# Shared builders for M3F.2 integrated Celebrity / Vineyard journeys.
# Ledger labels: confirmed | illustrative | shape_only (see m3f-acceptance-and-hardening.md).
module M3fScenarioHelper
  include CapacityGraphHelper
  include M3CCostScenarioHelper

  LEDGER_CONFIRMED = "confirmed"
  LEDGER_ILLUSTRATIVE = "illustrative"
  LEDGER_SHAPE_ONLY = "shape_only"

  def m3f_activated_graph!(prefix, departure_name, starts_on:, ends_on: starts_on,
    capacity_management: "unmanaged", actor: nil)
    actor ||= @actor
    supplier = create_capacity_supplier(@agency, "#{prefix} Supplier")
    departure = create_capacity_departure(@agency, name: departure_name, status: "draft")
    departure.update!(
      starts_on:,
      ends_on:,
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    ActivateDeparture.new(
      agency: @agency, actor:, departure:, lock_version: departure.lock_version
    ).call
    departure.reload
    assert_equal "active", departure.status
    assert departure.departure_reference.present?
    assert_not_nil departure.first_activated_at

    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix:, capacity_management:
    ).merge(supplier:, departure:, actor:)
    m3f_create_ready_cost!(graph)
    graph[:trigger] = m3f_create_confirmation_trigger!(graph)
    graph
  end

  def m3f_create_ready_cost!(graph)
    actor = graph[:actor] || @actor
    source = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "#{graph[:arrangement].name} zero cost"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "zero_cost", zero_cost_reason: "Included",
        currency: "USD"
      }
    ).call.record
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "M3F.2 command-driven readiness"
    ).call
    source.reload
  end

  def m3f_create_confirmation_trigger!(graph, description: "Confirm", fixed_quantity: 1)
    position = graph[:arrangement].supplier_commitment_trigger_definitions.maximum(:position).to_i + 1
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      committed_supplier: graph[:supplier],
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description:,
      fixed_quantity:,
      quantity_basis: "resource_units",
      position:
    )
  end

  def m3f_activate!(graph, elapsed_deadlines_acknowledged: false)
    actor = graph[:actor] || @actor
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version: graph[:version].reload,
      arrangement_lock_version: graph[:arrangement].reload.lock_version,
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Approved",
        confirmed_without_identifier_reason: "Later"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged:
    ).call
  end

  # Second Arrangement on an already-activated Departure (distinct contracting Supplier).
  def m3f_secondary_arrangement_graph!(departure:, supplier_name:, prefix:,
    capacity_management: "unmanaged", starts_on: nil, ends_on: nil, actor: nil)
    actor ||= @actor
    supplier = create_capacity_supplier(@agency, supplier_name)
    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix:, capacity_management:
    ).merge(supplier:, departure:, actor:)
    if starts_on
      graph[:occurrence_definition].update!(starts_on:, ends_on: ends_on || starts_on)
    end
    m3f_create_ready_cost!(graph)
    graph[:trigger] = m3f_create_confirmation_trigger!(graph)
    graph
  end

  def m3f_add_numeric_pool!(graph, quantity:, measurement_basis: "resource_units", label: "Guaranteed rooms")
    graph[:item_definition].update!(capacity_management: "managed")
    pair = classify_capacity_graph_pair(graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: graph[:supplier],
      inventory_mode: "block", measurement_basis:,
      effective_time_zone: "America/New_York"
    )
    CapacityPoolDefinition.create!(
      agency: @agency, departure: graph[:departure],
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair, capacity_pool: pool,
      label:, normalized_label: label.downcase,
      unit_label: measurement_basis == "traveler_positions" ? "seats" : "rooms",
      proposed_opening_quantity: quantity,
      evidence_kind: "contract", evidence_on: Date.current,
      evidence_reference_note: "#{label} block", override: false, position: 1
    )
    pool
  end

  def m3f_record_confirmed_response!(graph, reservation:, scope:, capacity_consequences: [])
    actor = graph[:actor] || @actor
    RecordSupplierReservationResponse.new(
      agency: @agency, actor:, reservation: reservation.reload,
      attributes: {
        channel: "portal",
        reference_note: "Confirmed",
        outcomes: { scope.id => { outcome_kind: "confirmed" } },
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed",
          confirmed_without_identifier_reason: "Portal"
        },
        capacity_consequences:
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def m3f_end_arrangement!(graph)
    actor = graph[:actor] || @actor
    CapacityPool.where(supplier_arrangement_id: graph[:arrangement].id).find_each do |pool|
      projection = CapacityProjection.find_by(
        agency_id: @agency.id, capacity_pool_id: pool.id, supplier_arrangement_id: graph[:arrangement].id
      )
      next if projection.nil? || projection.current_supplier_capacity.to_i <= 0

      WithdrawCapacity.new(
        agency: @agency, actor:, pool:,
        quantity: projection.current_supplier_capacity,
        projection_lock_version: projection.lock_version,
        idempotency_key: SecureRandom.uuid,
        effective_on: Time.current.in_time_zone(pool.effective_time_zone).to_date,
        attributes: {
          evidence_kind: "contract",
          evidence_on: Date.current,
          evidence_reference_note: "M3F.2 withdraw before ending"
        }
      ).call
    end

    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor:, arrangement: graph[:arrangement].reload,
      selected_cascade_keys: [],
      ending_reason: "planning_concluded"
    ).call
    payload = preview.record.payload
    selected = Array(payload["selected_cascade_keys"])
    if payload.fetch("blockers").any?
      selected = payload.fetch("cascades").map { |row| row["key"] }
      preview = PreviewEndSupplierArrangement.new(
        agency: @agency, actor:, arrangement: graph[:arrangement],
        selected_cascade_keys: selected,
        ending_reason: "planning_concluded"
      ).call
      payload = preview.record.payload
    end
    assert payload.fetch("blockers").empty?, payload.fetch("blockers").inspect
    EndSupplierArrangement.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      preview_token: preview.raw_token,
      idempotency_key: SecureRandom.uuid,
      selected_cascade_keys: Array(payload["selected_cascade_keys"]),
      ending_reason: "planning_concluded"
    ).call
    graph[:arrangement].reload
  end

  def m3f_deposit_attrs(**overrides)
    {
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: [],
      contributor_definition_ids: []
    }.merge(overrides)
  end

  def m3f_create_deposit!(graph, **attrs)
    actor = graph[:actor] || @actor
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor:, version: graph[:version].reload,
      attributes: m3f_deposit_attrs(**attrs),
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def m3f_deadline_attrs(**overrides)
    {
      deadline_type: "final_count_due",
      kind: "informational",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 7 },
      precision: "date_only",
      time_zone: "America/New_York",
      cardinality: "one_shared",
      coverage_links: [],
      commitment_lines: []
    }.merge(overrides)
  end

  def m3f_create_deadline!(graph, **attrs)
    actor = graph[:actor] || @actor
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor:, version: graph[:version].reload,
      attributes: m3f_deadline_attrs(**attrs),
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  # Confirmed M3C O1 per-person components (USD minor units).
  def m3f_create_celebrity_o1_cost!(graph)
    actor = graph[:actor] || @actor
    graph[:version].reload
    category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor:, arrangement_item: graph[:item],
      version_lock_version: graph[:version].lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Anonymous occupant" }
    ).call.record
    assumption = CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor:, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { supplier_resource_id: graph[:resource].id }
    ).call.record
    CELEBRITY_O1_ANONYMOUS_PROFILES.each do |profile|
      CreateSupplierCostOccupancyProfile.new(
        agency: @agency, actor:, assumption: assumption.reload,
        assumption_lock_version: assumption.lock_version, idempotency_key: SecureRandom.uuid,
        attributes: {
          label: profile[:label],
          resource_unit_count: profile[:resource_unit_count]
        },
        positions: Array.new(profile[:occupancy_positions].size, category.id)
      ).call
    end

    source = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        supplier_resource_id: graph[:resource].id,
        charging_supplier_id: graph[:supplier].id,
        label: "O1 cabin category"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record

    components = [
      {
        label: "First/second-position cruise fare",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
        role: "supplier_charge", kind: "unit_rate",
        quantity_basis: "occupancy_positions", from: 1, to: 2
      },
      {
        label: "Additional-position fare",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:additional_fare),
        role: "supplier_charge", kind: "unit_rate",
        quantity_basis: "occupancy_positions", from: 3, to: nil
      },
      {
        label: "NCCF",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:nccf),
        role: "supplier_charge", kind: "unit_rate",
        quantity_basis: "persons", from: nil, to: nil
      },
      {
        label: "First/second-position discount",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:first_second_discount),
        role: "supplier_credit", kind: "unit_rate",
        quantity_basis: "occupancy_positions", from: 1, to: 2
      },
      {
        label: "Additional-position discount",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:additional_discount),
        role: "supplier_credit", kind: "unit_rate",
        quantity_basis: "occupancy_positions", from: 3, to: nil
      },
      {
        label: "Taxes/fees/port charges",
        amount: CELEBRITY_O1_AMOUNTS.fetch(:taxes_fees_port_charges),
        role: "supplier_charge", kind: "unit_rate",
        quantity_basis: "persons", from: nil, to: nil
      }
    ]
    components.each_with_index do |spec, index|
      attrs = {
        label: spec[:label], economic_role: spec[:role],
        calculation_kind: spec[:kind], amount_minor_units: spec[:amount],
        quantity_basis: spec[:quantity_basis],
        position: index + 1, pass_through: false
      }
      attrs[:occupancy_position_from] = spec[:from] if spec[:from]
      attrs[:occupancy_position_to] = spec[:to] if spec[:to]
      CreateSupplierCostComponent.new(
        agency: @agency, actor:, definition: definition.reload,
        definition_lock_version: definition.lock_version,
        idempotency_key: SecureRandom.uuid,
        attributes: attrs
      ).call
    end
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "M3F.2 confirmed O1 amounts"
    ).call
    source.reload
  end

  # Confirmed excursion: $50 unit_rate, minimum_quantity_shortfall of 5.
  def m3f_create_excursion_cost!(graph, unit_rate_minor_units: 5_000, planned_persons: 3, minimum_quantity: 5)
    actor = graph[:actor] || @actor
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor:, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { expected_persons: planned_persons, expected_resource_units: 1 }
    ).call

    source = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Optional excursion"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    rate = CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition:,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per person", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: unit_rate_minor_units,
        quantity_basis: "persons", pass_through: false
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      base_links: [ { base_component_id: rate.id, direction: "add" } ],
      attributes: {
        label: "Minimum five", economic_role: "supplier_charge",
        calculation_kind: "minimum_quantity_shortfall", minimum_quantity:,
        quantity_basis: "persons", pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "M3F.2 confirmed excursion shortfall"
    ).call
    source.reload
  end

  # Illustrative Vineyard fixed coach + per-person tasting (not confirmed worksheet amounts).
  def m3f_create_vineyard_costs!(graph)
    actor = graph[:actor] || @actor
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor:, arrangement_item: graph[:item],
      idempotency_key: SecureRandom.uuid,
      attributes: { expected_persons: 12, expected_resource_units: 1 }
    ).call

    coach = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Coach hire"
      }
    ).call.record
    coach_def = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source: coach,
      source_lock_version: coach.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition: coach_def,
      definition_lock_version: coach_def.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Coach", economic_role: "supplier_charge",
        calculation_kind: "fixed", amount_minor_units: 120_000, pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: coach_def.reload,
      lock_version: coach_def.lock_version,
      readiness_provenance: "M3F.2 illustrative coach"
    ).call

    persons = CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "Per-person tasting"
      }
    ).call.record
    person_def = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source: persons,
      source_lock_version: persons.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition: person_def,
      definition_lock_version: person_def.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per person", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: 5_000,
        quantity_basis: "persons", pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor:, definition: person_def.reload,
      lock_version: person_def.lock_version,
      readiness_provenance: "M3F.2 illustrative tasting"
    ).call

    [ coach.reload, persons.reload ]
  end

  def m3f_add_dinner_items!(graph)
    version = graph[:version]
    departure = graph[:departure]
    arrangement = graph[:arrangement]
    actor = graph[:actor] || @actor
    %w[Standard Deluxe].each_with_index do |label, index|
      item = arrangement.arrangement_items.create!(agency: @agency, departure:)
      version.arrangement_item_definitions.create!(
        agency: @agency, departure:, supplier_arrangement: arrangement,
        arrangement_item: item, name: "#{label} Dinner", category: "dining",
        position: graph[:item_definition].position + index + 1,
        capacity_management: "unmanaged",
        default_service_provider: graph[:supplier]
      )
      occurrence = item.service_occurrences.create!(
        agency: @agency, departure:, supplier_arrangement: arrangement, status: "planned"
      )
      version.service_occurrence_definitions.create!(
        agency: @agency, departure:, supplier_arrangement: arrangement,
        arrangement_item: item, service_occurrence: occurrence,
        name: "#{label} Dinner service",
        starts_on: departure.starts_on, ends_on: departure.starts_on,
        time_zone: departure.time_zone,
        service_provider: graph[:supplier]
      )
      resource = item.supplier_resources.create!(
        agency: @agency, departure:, supplier_arrangement: arrangement
      )
      version.supplier_resource_definitions.create!(
        agency: @agency, departure:, supplier_arrangement: arrangement,
        arrangement_item: item, supplier_resource: resource,
        name: "#{label} seating", position: 1
      )
      source = SupplierCostSource.create!(
        agency: @agency, departure:,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        arrangement_item: item,
        charging_supplier: graph[:supplier],
        label: "#{label} Dinner included", position: index + 10
      )
      SupplierCostDefinition.create!(
        agency: @agency, departure:,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        supplier_cost_source: source,
        stage: "contracted", status: "forecast_ready", mode: "zero_cost",
        zero_cost_reason: "Included in package shape", currency: "USD",
        forecast_ready_by: actor, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:dinner-#{SecureRandom.hex(4)}",
        readiness_provenance: "M3F.2 shape-only dinner Items"
      )
    end
  end

  def m3f_add_prestay_occurrence!(graph, starts_on:, ends_on:)
    departure = graph[:departure]
    arrangement = graph[:arrangement]
    version = graph[:version]
    occurrence = graph[:item].service_occurrences.create!(
      agency: @agency, departure:, supplier_arrangement: arrangement, status: "planned"
    )
    version.service_occurrence_definitions.create!(
      agency: @agency, departure:, supplier_arrangement: arrangement,
      arrangement_item: graph[:item], service_occurrence: occurrence,
      name: "Hilton pre-stay",
      starts_on:, ends_on:,
      time_zone: departure.time_zone,
      service_provider: graph[:supplier]
    )
    occurrence
  end

  def m3f_assert_no_client_commercial_tables!
    %w[client_holds client_allocations travelers obligations payments].each do |table|
      assert_not ActiveRecord::Base.connection.data_source_exists?(table),
        "M3 must not invent #{table} (ledger: shape_only / out of scope)"
    end
  end
end
