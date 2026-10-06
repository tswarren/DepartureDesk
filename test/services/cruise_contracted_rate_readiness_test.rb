# frozen_string_literal: true

require "test_helper"

class CruiseContractedRateReadinessTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @version.reload
    CreateCruiseSupplierRateSchedule.new(**rate_args).call
    @version.reload
  end

  test "a reviewed contracted rate activates without a forecast or occupancy mix" do
    contracted = record_contracted!
    review_contract!(contracted)
    authorize_opening!
    confirm_agreement!
    activate_departure!

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource, stage: "contracted"
    ).call
    illustration = preview.illustrations.find { |row| row.key == "double" }
    assert_equal "pending", illustration.commission_state
    assert_equal "pending", illustration.net_state
    assert_nil illustration.net_minor_units
    assert illustration.gross_minor_units.positive?

    result = activate!
    assert_equal :created, result.status
    contracted.reload
    refute contracted.forecast_ready?
    assert contracted.contract_review_current?
    assert_equal 0, @version.supplier_cost_occupancy_profiles.count
    assert_equal "unspecified", contracted.commission_treatment
    assert_equal 0, contracted.supplier_cost_components.where(economic_role: "expected_commission").count

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copy = successor.supplier_cost_definitions.find_by!(stage: "contracted")
    assert copy.contract_review_current?
    refute copy.forecast_ready?
  end

  test "missing contract review or opening authority still blocks activation" do
    record_contracted!
    confirm_agreement!
    authorize_opening!
    missing_review = readiness
    assert_includes missing_review.blockers.map(&:code), :cruise_contracted_rates_missing
    refute missing_review.ready?

    review_contract!(contracted_definition)
    pool_definition.update!(
      evidence_kind: nil, evidence_on: nil, evidence_reference_note: nil, override: false
    )
    missing_authority = readiness
    assert_includes missing_authority.blockers.map(&:code), :opening_authority_incomplete
    refute_includes missing_authority.blockers.map(&:code), :cruise_contracted_rates_missing
  end

  test "occupancy edits keep the contract review and rate edits clear it" do
    contracted = review_contract!(record_contracted!)
    save_occupancy!(double: 6)
    contracted.reload
    assert contracted.contract_review_current?
    refute contracted.forecast_ready?

    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: contracted.lock_version,
      readiness_provenance: "Occupancy recorded for planning",
      stage: "contracted"
    ).call
    assert contracted.reload.forecast_ready?
    assert contracted.contract_review_current?

    save_occupancy!(double: 4)
    contracted.reload
    assert contracted.contract_review_current?
    refute contracted.forecast_ready?

    UpdateCruiseSupplierRateSchedule.new(
      **rate_args.except(:idempotency_key, :stage).merge(
        terms: smith_terms.merge(first_second_fare: "1700.00"),
        stage: "contracted",
        definition_lock_version: contracted.lock_version
      )
    ).call
    refute contracted.reload.contract_review_current?
  end

  test "a forecast without occupancy reports the missing input and does not invent commission" do
    review_contract!(record_contracted!)
    error = assert_raises(AgencyCommand::Error) do
      MarkCruiseSupplierRateScheduleForecastReady.new(
        agency: @agency,
        actor: @actor,
        arrangement: @arrangement,
        resource: @resource,
        definition_lock_version: contracted_definition.lock_version,
        readiness_provenance: "No occupancy yet",
        stage: "contracted"
      ).call
    end
    assert_equal "Add usage assumptions for this cost context.", error.message

    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version.reload
    ).call
    source = forecast.arrangements.flat_map(&:sources).find { |entry| entry.definition_id.nil? }
    assert source
    assert_includes source.warnings.map { |warning| warning[:code] }, :no_selected_stage
    assert_equal 0, source.totals.expected_commission_minor_units
    assert_equal 0, source.totals.expected_net_cost_after_commission_minor_units
  end

  test "explicit none records no commission without a zero component" do
    UpdateCruiseSupplierRateSchedule.new(
      **rate_args.except(:idempotency_key).merge(
        commission: { method: "none" },
        definition_lock_version: estimate_definition.lock_version
      )
    ).call

    definition = estimate_definition
    assert definition.noncommissionable?
    assert_equal 0, definition.supplier_cost_components.where(economic_role: "expected_commission").count
    assert_nil definition.supplier_cost_components.find_by(amount_minor_units: 0, economic_role: "expected_commission")

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    illustration = preview.illustrations.find { |row| row.key == "double" }
    assert_equal "none", preview.commission_method
    assert_equal "none", illustration.commission_state
    assert_nil illustration.commission_minor_units
    assert illustration.gross_minor_units.positive?
    assert_equal illustration.gross_minor_units, illustration.net_minor_units

    save_occupancy!(double: 2)
    definition = estimate_definition.reload
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: definition.lock_version,
      readiness_provenance: "No commission expected",
      stage: "estimate"
    ).call
    source = selected_forecast_source
    assert source.complete
    assert source.totals.forecast_supplier_cost_minor_units.positive?
    assert_equal 0, source.totals.expected_commission_minor_units
    assert_equal source.totals.forecast_supplier_cost_minor_units,
      source.totals.expected_net_cost_after_commission_minor_units
  end

  test "a completed forecast leaves unknown commission unresolved" do
    contracted = review_contract!(record_contracted!)
    save_occupancy!(double: 2)
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: contracted.reload.lock_version,
      readiness_provenance: "Occupancy recorded for planning",
      stage: "contracted"
    ).call

    source = selected_forecast_source
    assert source.complete
    assert source.totals.forecast_supplier_cost_minor_units.positive?
    assert_nil source.totals.expected_commission_minor_units
    assert_nil source.totals.expected_net_cost_after_commission_minor_units

    offer = CreateServiceOfferFromSource.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: @arrangement.id,
        supplier_arrangement_version_id: @version.id,
        arrangement_item_id: cruise_item.arrangement_item_id,
        service_occurrence_id: cruise_occurrence.service_occurrence_id,
        supplier_resource_id: @resource.id,
        client_title: "O1 illustrative"
      }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency,
      actor: @actor,
      offer: offer,
      idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "occupancy_positions", amount: "210.00" }
    ).call
    economics = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency,
      actor: @actor,
      offer: offer,
      scenario: {
        persons: 2,
        resource_units: 1,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call
    assert_equal :unknown, economics.status
    assert_match(/commission is not recorded/i, economics.reason)
    assert_nil economics.expected_commission_minor_units
    assert_nil economics.indicative_margin_minor_units
  end

  test "an additional unreviewed cabin source blocks activation" do
    contracted = review_contract!(record_contracted!)
    extra = CreateSupplierCostSource.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: cruise_item.arrangement_item_id,
        service_occurrence_id: cruise_occurrence.service_occurrence_id,
        supplier_resource_id: @resource.id,
        charging_supplier_id: @contractor.id,
        label: "Supplemental O1 cost"
      }
    ).call.record

    result = readiness
    source_blockers = result.blockers.select { |blocker| blocker.code == :cruise_contracted_rates_missing }
    assert_equal [ "cost_sources.#{extra.id}" ], source_blockers.map(&:path)
    refute result.ready?
    selected_ids = result.cost_selections.map { |source, _definition| source.id }
    assert_includes selected_ids, contracted.supplier_cost_source_id
    refute_includes selected_ids, extra.id
  end

  test "a previously forecast-ready omission still means none" do
    contracted = record_contracted!
    save_occupancy!(double: 2)
    contracted.reload
    contracted.update_columns(
      status: "forecast_ready",
      forecast_ready_by_id: @actor.id,
      forecast_ready_at: Time.current,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(contracted),
      readiness_provenance: "Earlier readiness",
      omitted_commission_means_none: true,
      updated_at: Time.current
    )

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource, stage: "contracted"
    ).call
    assert_equal "none", preview.commission_method
    assert_equal "unspecified", contracted.reload.commission_treatment
    assert_equal 0, contracted.supplier_cost_components.where(economic_role: "expected_commission").count
    refute contracted.contract_review_current?

    source = selected_forecast_source
    assert source.complete
    assert source.totals.forecast_supplier_cost_minor_units.positive?
    assert_equal 0, source.totals.expected_commission_minor_units
    assert_equal source.totals.forecast_supplier_cost_minor_units,
      source.totals.expected_net_cost_after_commission_minor_units
  end

  private

  def smith_terms
    {
      first_second_fare: "1624.00",
      additional_fare: "406.00",
      single_supplement: "1624.00",
      nccf: "320.00",
      first_second_discount: "150.00",
      additional_discount: "37.50",
      taxes_fees: "137.00"
    }
  end

  def rate_args
    {
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      terms: smith_terms,
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    }
  end

  def record_contracted!
    RecordCruiseContractedRates.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def review_contract!(definition)
    MarkCruiseSupplierRateScheduleContractReviewed.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: definition.lock_version,
      contract_review_provenance: "Signed group contract"
    ).call.record
  end

  def cruise_item
    @version.arrangement_item_definitions.sole
  end

  def cruise_occurrence
    @version.service_occurrence_definitions.sole
  end

  def selected_forecast_source
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: @version.reload
    ).call
    forecast.arrangements.flat_map(&:sources).find { |entry| entry.definition_id.present? }
  end

  def estimate_definition
    @version.supplier_cost_definitions.find_by!(stage: "estimate")
  end

  def contracted_definition
    @version.supplier_cost_definitions.find_by!(stage: "contracted")
  end

  def pool_definition
    @version.capacity_pool_definitions.joins(:capacity_pool)
      .find_by!(capacity_pools: { supplier_resource_id: @resource.id })
  end

  def authorize_opening!
    pool_definition.update!(
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin block"
    )
  end

  def confirm_agreement!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-09-13",
      group_creation_date: "2026-09-13"
    ).call
  end

  def activate_departure!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
  end

  def readiness
    SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
  end

  def activate!
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true
    ).call
  end

  def save_occupancy!(expected_cabins)
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: expected_cabins,
      version_lock_version: @version.reload.lock_version
    ).call
  end
end
