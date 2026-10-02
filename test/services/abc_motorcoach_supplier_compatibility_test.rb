# frozen_string_literal: true

require "test_helper"

class AbcMotorcoachSupplierCompatibilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @contractor = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "ABC Motorcoach" },
      categories: [ "ground_transportation" ]
    ).call.record
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Harbor", last_name: "Contracting", status: "active"
    )
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 3),
        ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "ABC Motorcoach charter",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      }
    ).call.record
    @version = @arrangement.versions.sole
  end

  test "shipped supplier commands store the charter and expose the named limits" do
    hotel_item = create_item("Hotel → Port")
    airport_item = create_item("Port → Airport")
    mark_managed!(hotel_item)
    mark_managed!(airport_item)
    hotel_resource = create_resource(hotel_item, "Motorcoach")
    airport_resource = create_resource(airport_item, "Motorcoach")
    hotel_occurrence = create_occurrence(
      hotel_item, "Hotel → Port",
      starts_on: "2027-11-06", ends_on: "2027-11-06",
      starts_at_local: "10:00", ends_at_local: "11:00",
      time_zone: "America/New_York",
      departure_port_name: "Hilton Fort Lauderdale Marina",
      return_port_name: "Port Everglades"
    )
    airport_occurrence = create_occurrence(
      airport_item, "Port → Airport",
      starts_on: "2027-11-13", ends_on: "2027-11-13",
      starts_at_local: "09:30", ends_at_local: "10:30",
      time_zone: "America/New_York",
      departure_port_name: "Port Everglades",
      return_port_name: "Fort Lauderdale-Hollywood International Airport"
    )

    assert_equal %w[ground_transportation ground_transportation], item_categories
    assert_equal [ 10, 0 ], local_time(hotel_occurrence, :starts_at_local)
    assert_equal [ 9, 30 ], local_time(airport_occurrence, :starts_at_local)
    assert_equal 15, resource_definition(hotel_resource).maximum_occupancy
    assert_equal 15, resource_definition(airport_resource).maximum_occupancy
    assert_not @version.arrangement_item_definitions.exists?(name: "Airport → Port")
    assert_not ServiceOffer.exists?(departure_id: @departure.id)
    assert_empty @version.supplier_agreement_references
    assert_empty @version.supplier_agreement_reference_absences

    classify!(hotel_item, hotel_occurrence, hotel_resource, "pooled")
    classify!(airport_item, airport_occurrence, airport_resource, "pooled")
    configure_pool!(hotel_item, hotel_occurrence, hotel_resource, 1)
    configure_pool!(airport_item, airport_occurrence, airport_resource, 1)
    hotel_pool = pool_for(hotel_occurrence, hotel_resource)
    airport_pool = pool_for(airport_occurrence, airport_resource)

    assert_equal "block", hotel_pool.inventory_mode
    assert_equal "resource_units", hotel_pool.measurement_basis
    assert_equal "motorcoaches", pool_definition(hotel_pool).unit_label
    assert_equal 1, pool_definition(hotel_pool).proposed_opening_quantity
    assert_equal 1, pool_definition(airport_pool).proposed_opening_quantity
    assert_equal 15, resource_definition(hotel_resource).maximum_occupancy * pool_definition(hotel_pool).proposed_opening_quantity
    assert_empty CapacityPool.where(supplier_arrangement: @arrangement, measurement_basis: "traveler_positions")

    on_request_error = assert_raises(AgencyCommand::Error) do
      configure_pool!(hotel_item, hotel_occurrence, hotel_resource, 2, inventory_mode: "on_request")
    end
    assert_match(/Nonnumeric pools cannot include a proposed opening quantity/, on_request_error.message)
    second_pool_error = assert_raises(AgencyCommand::Error) do
      configure_pool!(hotel_item, hotel_occurrence, hotel_resource, nil, inventory_mode: "on_request")
    end
    assert_match(/already has a Pool/, second_pool_error.message)
    assert_equal 1, CapacityPool.where(service_occurrence: hotel_occurrence).count

    price_segment!(hotel_item, hotel_occurrence, hotel_resource, 20_000, 1)
    price_segment!(airport_item, airport_occurrence, airport_resource, 17_500, 1)
    assert_equal 37_500, forecast_total
    assert_nil usage_for(hotel_occurrence, hotel_resource).expected_persons

    update_usage!(hotel_occurrence, hotel_resource, 2)
    assert_equal 57_500, forecast_total
    update_usage!(hotel_occurrence, hotel_resource, 1)
    assert_equal 37_500, forecast_total

    hotel_deposit = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 20_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: [ coverage(hotel_item, hotel_occurrence, hotel_resource, hotel_pool) ]
    )
    airport_deposit = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 17_500,
      quantity_basis: "capacity_pool_units",
      coverage_links: [ coverage(airport_item, airport_occurrence, airport_resource, airport_pool) ]
    )
    fixed_parent_error = assert_raises(AgencyCommand::Error) do
      create_deposit!(
        amount_shape: "cumulative_target",
        target_amount_minor_units: 37_500,
        contributor_definition_ids: [ hotel_deposit.id, airport_deposit.id ],
        coverage_links: [
          coverage(hotel_item, hotel_occurrence, hotel_resource, nil),
          coverage(airport_item, airport_occurrence, airport_resource, nil)
        ]
      )
    end
    assert_match(/Fixed cumulative targets do not use contributor links/, fixed_parent_error.message)
    charter_deposit = create_deposit!(
      amount_shape: "cumulative_target",
      rate_minor_units: 20_000,
      quantity_basis: "capacity_pool_units",
      contributor_definition_ids: [ hotel_deposit.id, airport_deposit.id ],
      coverage_links: [
        coverage(hotel_item, hotel_occurrence, hotel_resource, hotel_pool),
        coverage(airport_item, airport_occurrence, airport_resource, airport_pool)
      ]
    )
    hotel_preview = evaluate_deposit(hotel_deposit, :preview)
    airport_preview = evaluate_deposit(airport_deposit, :preview)
    charter_preview = evaluate_deposit(charter_deposit, :preview)
    assert_equal 20_000, hotel_preview[:amount_minor_units]
    assert_equal 17_500, airport_preview[:amount_minor_units]
    assert_equal 37_500, hotel_preview[:amount_minor_units] + airport_preview[:amount_minor_units]
    assert_equal 2_500, charter_preview[:amount_minor_units]
    assert_equal 1, hotel_preview[:inputs]["sources"].size
    assert_equal hotel_pool.id, hotel_preview[:inputs]["sources"].sole["capacity_pool_id"]

    hotel_deadline = create_deadline!(hotel_item, "2027-11-03")
    airport_deadline = create_deadline!(airport_item, "2027-11-10")
    assert_equal "final_count_due", hotel_deadline.deadline_type
    assert_equal "date_only", hotel_deadline.precision
    assert_equal "2027-11-03", hotel_deadline.rule_parameters["date"]
    assert_equal "2027-11-10", airport_deadline.rule_parameters["date"]
    assert_equal "2027-11-03", hotel_deposit.rule_parameters["date"]
    assert_equal hotel_item.id, hotel_deadline.supplier_deadline_definition_coverage_links.sole.arrangement_item_id
    assert_equal 1, pool_definition(hotel_pool).proposed_opening_quantity

    RecordSupplierConfirmationEvidence.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: @version,
      recorded_at: Time.current,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "ABC charter confirmation",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      }
    ).call
    assert SupplierConfirmation.exists?(supplier_arrangement_version_id: @version.id)

    resource_update = UpdateSupplierResource.new(
      agency: @agency, actor: @admin, definition: resource_definition(hotel_resource),
      attributes: { name: "Motorcoach", maximum_occupancy: 16 },
      lock_version: resource_definition(hotel_resource).lock_version
    ).call
    assert_equal :updated, resource_update.status
    UpdateSupplierResource.new(
      agency: @agency, actor: @admin, definition: resource_definition(hotel_resource).reload,
      attributes: { name: "Motorcoach", maximum_occupancy: 15 },
      lock_version: resource_definition(hotel_resource).lock_version
    ).call

    component = cost_component_for(hotel_occurrence, hotel_resource)
    component_update = UpdateSupplierCostComponent.new(
      agency: @agency, actor: @admin, component: component,
      attributes: { amount_minor_units: 20_100 },
      lock_version: component.lock_version
    ).call
    assert_equal :updated, component_update.status
    UpdateSupplierCostComponent.new(
      agency: @agency, actor: @admin, component: component.reload,
      attributes: { amount_minor_units: 20_000 },
      lock_version: component.lock_version
    ).call
    definition = component.reload.supplier_cost_definition
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "ABC charter per confirmed coach"
    ).call

    hotel_deposit.reload
    deposit_update = UpdateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, definition: hotel_deposit,
      attributes: deposit_attributes(
        amount_shape: "quantity_times_rate",
        rate_minor_units: 20_100,
        quantity_basis: "capacity_pool_units",
        coverage_links: [ coverage(hotel_item, hotel_occurrence, hotel_resource, hotel_pool) ]
      ),
      lock_version: hotel_deposit.lock_version
    ).call
    assert_equal :updated, deposit_update.status
    UpdateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, definition: hotel_deposit.reload,
      attributes: deposit_attributes(
        amount_shape: "quantity_times_rate",
        rate_minor_units: 20_000,
        quantity_basis: "capacity_pool_units",
        coverage_links: [ coverage(hotel_item, hotel_occurrence, hotel_resource, hotel_pool) ]
      ),
      lock_version: hotel_deposit.lock_version
    ).call

    hotel_deadline.reload
    deadline_update = UpdateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, definition: hotel_deadline,
      attributes: deadline_attributes(hotel_item, "2027-11-03", warning_lead_days: 7),
      lock_version: hotel_deadline.lock_version
    ).call
    assert_equal :updated, deadline_update.status
    assert_equal 1, pool_definition(hotel_pool).reload.proposed_opening_quantity

    activate_departure!
    activation = ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "ABC charter activation",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
    assert_equal :created, activation.status

    assert_equal 37_500, forecast_total
    increase = IncreaseCapacity.new(
      agency: @agency, actor: @admin, pool: hotel_pool, quantity: 1,
      projection_lock_version: hotel_pool.capacity_projection.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        evidence_kind: "contract", evidence_on: Date.current,
        evidence_reference_note: "Second Hotel → Port coach", override: false
      }
    ).call
    assert_equal :created, increase.status
    assert_equal 2, hotel_pool.capacity_projection.reload.current_supplier_capacity
    assert_equal 1, airport_pool.capacity_projection.reload.current_supplier_capacity
    assert_equal 30, resource_definition(hotel_resource).maximum_occupancy * hotel_pool.capacity_projection.current_supplier_capacity
    assert_equal 37_500, forecast_total

    hotel_materialized = evaluate_deposit(hotel_deposit.reload, :materialize)
    airport_materialized = evaluate_deposit(airport_deposit.reload, :materialize)
    charter_materialized = evaluate_deposit(charter_deposit.reload, :materialize)
    assert_equal 20_000, hotel_materialized[:amount_minor_units]
    assert_equal 17_500, airport_materialized[:amount_minor_units]
    assert_equal "established_opening", hotel_materialized[:inputs]["quantity_phase"]
    assert_equal 1, hotel_materialized[:inputs]["quantity"]
    assert_equal 22_500, charter_materialized[:amount_minor_units]
    charter_rows = charter_materialized[:components].index_by { |row| row["capacity_pool_id"] }
    assert_equal 2, charter_rows.fetch(hotel_pool.id)["retained_quantity"]
    assert_equal 20_000, charter_rows.fetch(hotel_pool.id)["remaining_minor_units"]
    assert_equal 1, charter_rows.fetch(airport_pool.id)["retained_quantity"]
    assert_equal 2_500, charter_rows.fetch(airport_pool.id)["remaining_minor_units"]

    coach_quantity = hotel_pool.capacity_projection.reload.current_supplier_capacity
    occurrences = SupplierDeadlineOccurrence.where(
      supplier_arrangement_version_id: @version.id, deadline_type: "final_count_due"
    )
    assert_equal 2, occurrences.count
    assert_empty SupplierCommitment.where(supplier_deadline_occurrence_id: occurrences.select(:id))
    assert_equal coach_quantity, hotel_pool.capacity_projection.reload.current_supplier_capacity

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal :created, successor.status
    assert_equal [ hotel_item.id, airport_item.id ], successor.record.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
  end

  private

  def create_item(name)
    CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name, category: "ground_transportation", default_service_provider_id: @contractor.id }
    ).call.record
  end

  def mark_managed!(item)
    definition = @version.arrangement_item_definitions.find_by!(arrangement_item: item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @admin, definition: definition,
      capacity_management: "managed", lock_version: definition.lock_version
    ).call
  end

  def create_resource(item, name)
    CreateSupplierResource.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name, maximum_occupancy: 15 }
    ).call.record
  end

  def create_occurrence(item, name, attributes)
    CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: name }.merge(attributes)
    ).call.record
  end

  def classify!(item, occurrence, resource, classification)
    ClassifyCapacityPair.new(
      agency: @agency, actor: @admin, item: item,
      service_occurrence: occurrence, supplier_resource: resource,
      classification: classification, version_lock_version: lock_version
    ).call
  end

  def configure_pool!(item, occurrence, resource, quantity, inventory_mode: "block")
    attributes = {
      inventory_mode: inventory_mode,
      measurement_basis: "resource_units",
      unit_label: "motorcoaches",
      label: "#{definition_for(occurrence).name} coach",
      evidence_kind: "contract",
      evidence_on: "2026-09-30",
      evidence_reference_note: "ABC charter"
    }
    attributes[:proposed_opening_quantity] = quantity unless quantity.nil?
    ConfigureCapacityPairWithPool.new(
      agency: @agency, actor: @admin, item: item,
      service_occurrence: occurrence, supplier_resource: resource,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      pool_attributes: attributes
    ).call
  end

  def price_segment!(item, occurrence, resource, amount_minor_units, coaches)
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id,
        expected_resource_units: coaches
      }
    ).call
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id,
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id,
        charging_supplier_id: @contractor.id,
        label: definition_for(occurrence).name
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Per confirmed coach", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount_minor_units: amount_minor_units,
        quantity_basis: "resource_units", pass_through: false
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "ABC charter per confirmed coach"
    ).call
  end

  def create_deposit!(attributes)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      attributes: deposit_attributes(attributes),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def deposit_attributes(attributes)
    {
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-11-03" },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: [],
      contributor_definition_ids: []
    }.merge(attributes)
  end

  def create_deadline!(item, date)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      attributes: deadline_attributes(item, date),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def deadline_attributes(item, date, warning_lead_days: nil)
    {
      deadline_type: "final_count_due",
      kind: "actionable",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => date },
      precision: "date_only",
      time_zone: "America/New_York",
      cardinality: "one_shared",
      warning_lead_days: warning_lead_days,
      coverage_links: [ { arrangement_item_id: item.id } ],
      commitment_lines: []
    }
  end

  def coverage(item, occurrence, resource, pool)
    {
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id,
      capacity_pool_id: pool&.id
    }
  end

  def evaluate_deposit(definition, mode)
    SupplierDepositAmountEvaluator.call(
      definition: definition, version: @version.reload, arrangement: @arrangement, mode: mode
    )
  end

  def forecast_total
    EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement
    ).call.totals.forecast_supplier_cost_minor_units
  end

  def update_usage!(occurrence, resource, coaches)
    assumption = usage_for(occurrence, resource)
    UpdateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, assumption: assumption,
      attributes: { expected_resource_units: coaches },
      lock_version: assumption.lock_version
    ).call
  end

  def activate_departure!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
  end

  def item_categories
    @version.arrangement_item_definitions.order(:position).pluck(:category)
  end

  def definition_for(occurrence)
    @version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
  end

  def resource_definition(resource)
    @version.supplier_resource_definitions.find_by!(supplier_resource: resource)
  end

  def resource_name(resource)
    resource_definition(resource).name
  end

  def pool_for(occurrence, resource)
    pool_definition_for(occurrence, resource).capacity_pool
  end

  def pool_definition(pool)
    @version.capacity_pool_definitions.find_by!(capacity_pool: pool)
  end

  def pool_definition_for(occurrence, resource)
    @version.capacity_pool_definitions.find_by!(
      service_occurrence: occurrence, supplier_resource: resource, capacity_pool: CapacityPool.where(inventory_mode: "block")
    )
  end

  def usage_for(occurrence, resource)
    @version.supplier_cost_usage_assumptions.find_by!(
      service_occurrence_id: occurrence.id, supplier_resource_id: resource.id
    )
  end

  def cost_component_for(occurrence, resource)
    source = @version.supplier_cost_sources.find_by!(
      service_occurrence_id: occurrence.id, supplier_resource_id: resource.id
    )
    source.supplier_cost_definitions.sole.supplier_cost_components.sole
  end

  def local_time(occurrence, field)
    value = definition_for(occurrence).public_send(field)
    [ value.hour, value.min ]
  end

  def lock_version
    @version.reload.lock_version
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
