# frozen_string_literal: true

require "test_helper"

class M4d1CruiseInventoryMaintenanceTest < ActiveSupport::TestCase
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
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
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    @item = sailing.record.item
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @pool = cabin.record.pool
    @deposit = create_initial_deposit!
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version.reload
    )
  end

  test "activated cabin quantity follows the projection and a successor separates carried from supplemental" do
    activate_original!
    summary = compile
    row = summary.cabin_rows.sole

    assert_equal "Current active capacity: 8 cabins", row.quantity_label
    assert_equal "Original opening quantity: 8 cabins", row.opening_quantity_label
    assert_equal 8, row.quantity
    assert_not row.carried

    RecordCruiseSameTermsCapacityIncrease.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      pool_id: @pool.id,
      quantity: 4,
      rate_minor_units: 5_000,
      evidence: evidence,
      idempotency_key: "projection-increase"
    ).call
    @pool.reload
    summary = compile
    row = summary.cabin_rows.sole

    assert_equal 12, @pool.capacity_projection.current_supplier_capacity
    assert_equal 8, opening_quantity(@version)
    assert_equal "Current active capacity: 12 cabins", row.quantity_label
    assert_equal "Original opening quantity: 8 cabins", row.opening_quantity_label
    assert_equal [ @deposit.id, @deposit.lock_version ], deposit_identity

    successor = create_supplemental!
    summary = compile(version: successor)
    carried = summary.cabin_rows.find(&:carried)
    supplemental = summary.cabin_rows.reject(&:carried).sole

    assert_equal "Carried from active terms", carried.quantity_label
    assert_nil carried.quantity
    assert_equal "4 cabins", supplemental.quantity_label
    assert_equal 4, supplemental.quantity
    assert_equal "2 cabin categories", summary.sections.find { |section| section.key == "cabins" }.detail
    assert_equal 8, opening_quantity(successor, @pool)

    active = compile(version: @arrangement.reload.governing_version)
    assert_equal [ "Current active capacity: 12 cabins" ], active.cabin_rows.map(&:quantity_label)
    assert_not_includes active.cabin_rows.map(&:name), "Supplemental O1 block"
    assert summary.maintenance_steps.map(&:code).include?(:opening_authority_incomplete)
    assert summary.maintenance_steps.map(&:code).include?(:cruise_agreement_unconfirmed)
    assert summary.maintenance_steps.map(&:code).include?(:cruise_contracted_rates_missing)
    assert summary.maintenance_steps.map(&:code).include?(:cruise_deposit_treatment_missing)
  end

  test "changed terms uses the selected cabin category" do
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: "Deluxe Inside", supplier_code: "DI", maximum_occupancy: 2 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version.reload
    )
    activate_original!
    successor = CreateCruiseSupplementalBlock.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      maximum_occupancy: 2,
      opening_quantity: 4,
      supplier_resource_id: cabin.record.resource.id
    ).call.record.version
    definition = successor.supplier_resource_definitions.find_by!(name: "Supplemental DI block")

    assert_equal "DI", definition.supplier_code
    assert_not_equal cabin.record.resource.id, definition.supplier_resource_id
  end

  test "a connected client service is unchanged by the supplemental block and by activating it" do
    activate_original!
    offer = ConnectCruiseServiceOffer.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new",
        title: "Oceanview",
        supplier_arrangement_version_id: @version.id,
        use_tentative_draft: false,
        arrangement_lock_version: @version.reload.lock_version,
        arrangement_item_id: @item.id,
        supplier_resource_ids: [ @resource.id ]
      }
    ).call.record
    draft = offer.editable_draft_version
    draft.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: offer, currency: "USD",
      mode: "zero_price", zero_price_reason: "Included for now"
    )
    draft.create_sales_state!(agency: @agency, departure: @departure, sales_enabled: true)
    before = client_snapshot(offer)

    successor = create_supplemental!
    supplemental_resource_id = successor.supplier_resource_definitions
      .find_by!(name: "Supplemental O1 block").supplier_resource_id

    assert_equal before, client_snapshot(offer)
    assert_not_includes before[:bindings].map(&:first), supplemental_resource_id

    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-10-20",
      group_creation_date: "2026-09-13",
      deposit_treatment: "No additional initial deposit for this block."
    ).call
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: successor.reload
    )
    successor.capacity_pool_definitions.where(evidence_reference_note: nil).find_each do |definition|
      definition.update!(
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed supplemental block"
      )
    end
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version: successor.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplemental block confirmed",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call

    assert_equal successor.id, @arrangement.reload.governing_version_id
    assert_equal before, client_snapshot(offer.reload)
    assert_not_includes client_snapshot(offer)[:bindings].map(&:first), supplemental_resource_id
  end

  private

  def compile(version: nil)
    shape = DetectCruiseArrangementShape.new(
      agency: @agency, arrangement: @arrangement.reload, version: version
    ).call
    CompileCruiseCompositionSummary.new(agency: @agency, arrangement: @arrangement, shape: shape).call
  end

  def create_initial_deposit!
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool: @pool)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @actor,
      version: @version,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-10-13" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ {
          capacity_pool_id: @pool.id,
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: definition.service_occurrence_id,
          supplier_resource_id: definition.supplier_resource_id
        } ]
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def activate_original!
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
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
    @version.reload
  end

  def create_supplemental!
    CreateCruiseSupplementalBlock.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      maximum_occupancy: 3,
      opening_quantity: 4
    ).call.record.version.reload
  end

  def evidence
    {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-10-01",
      evidence_reference_note: "Supplier added four O1 cabins"
    }
  end

  def opening_quantity(version, pool = @pool)
    version.capacity_pool_definitions.find_by!(capacity_pool: pool).proposed_opening_quantity
  end

  def deposit_identity
    record = @version.supplier_deposit_requirement_definitions.find(@deposit.id)
    [ record.id, record.lock_version ]
  end

  def client_snapshot(offer)
    version = offer.editable_draft_version
    {
      bindings: version.source_bindings.order(:id).pluck(:supplier_resource_id, :supplier_arrangement_version_id),
      price: version.price_definition.attributes.slice("id", "mode", "currency"),
      choices: version.choice_options.order(:position).map { |option|
        option.attributes.slice("id", "client_rate_category_key", "price_effect_minor_units")
      },
      sales_enabled: version.sales_state.sales_enabled
    }
  end
end
