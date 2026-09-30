# frozen_string_literal: true

require "test_helper"

class M4d1CruiseActivationReviewTest < ActiveSupport::TestCase
  include CapacityGraphHelper
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_sailing!
    @pool = add_cabin!(@setup, name: "Prime Oceanview", code: "O1", inventory_mode: "block", quantity: 8)
  end

  test "the compiler is read-only and does not redefine readiness" do
    prepare_post_eligible!
    audits = AuditEvent.count
    tranches = SupplierDepositRequirementTranche.count

    review = compile

    assert_equal audits, AuditEvent.count
    assert_equal tranches, SupplierDepositRequirementTranche.count
    assert_equal true, review.readiness_ready?
    assert_equal true, review.cruise_post_allowed?
    assert_equal true, review.triggers_completely_represented?
    assert_includes review.consequences, "No confirmation-triggered commitments will open."
    refute review.requirements.find { |row| row.key == "initial_deposit" }.recorded?
  end

  test "a selected estimate stays readiness-ready and is not cruise post eligible" do
    prepare_post_eligible!
    add_estimate_source!
    review = compile

    assert_equal true, review.readiness_ready?
    assert_equal false, review.cruise_post_allowed?
    assert_equal true, review.cost_sources_completely_represented?
    assert review.cost_rows.any? { |row| row.stage_label == "Estimate" }
  end

  test "an unrepresented cost selection disables the cruise post" do
    prepare_post_eligible!
    real = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @setup[:arrangement], version: @setup[:version].reload
    ).call
    source = real.cost_selections.first.first
    definition = Object.new
    definition.define_singleton_method(:contracted?) { false }
    definition.define_singleton_method(:estimate?) { false }
    definition.define_singleton_method(:stage) { "other" }
    replaced = SupplierArrangementActivationReadiness::Result.new(
      version: real.version,
      blockers: real.blockers,
      cost_selections: [ [ source, definition ] ]
    )
    readiness = Object.new
    readiness.define_singleton_method(:call) { replaced }

    review = with_constructor(SupplierArrangementActivationReadiness, readiness) { compile }

    assert_equal false, review.cost_sources_completely_represented?
    assert_equal false, review.cruise_post_allowed?
  end

  test "an unrepresented trigger disables the cruise post" do
    prepare_post_eligible!
    with_unrepresented_trigger do
      review = compile
      assert_equal false, review.triggers_completely_represented?
      assert_equal false, review.cruise_post_allowed?
    end
    restored = compile
    assert_equal true, restored.triggers_completely_represented?
  end

  test "known blockers name the cruise correction and unknown blockers stay advanced" do
    definition = @setup[:version].capacity_pool_definitions.find_by!(capacity_pool_id: @pool.id)
    definition.update_columns(
      evidence_kind: nil, evidence_on: nil, evidence_reference_note: nil, override: false
    )
    review = compile
    opening = review.blockers.find { |row| row.code == :opening_authority_incomplete }
    assert_equal :cabin_categories, opening.destination
    assert_match(/opening evidence is incomplete/i, opening.message)
    rates = review.blockers.find { |row| row.code == :cruise_contracted_rates_missing }
    assert_equal :supplier_rates, rates.destination
    agreement = review.blockers.find { |row| row.code == :cruise_agreement_unconfirmed }
    assert_equal :agreement, agreement.destination

    definition.update_columns(proposed_opening_quantity: nil)
    missing = compile.blockers.find { |row| row.code == :opening_authority_incomplete }
    assert_match(/does not have an opening cabin quantity/i, missing.message)

    definition.update_columns(
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin terms"
    )
    prepare_post_eligible!
    requested = add_cabin!(@setup, name: "Concierge", code: "C1", inventory_mode: "on_request")
    tracked = compile
    cabin = tracked.cabins.find { |row| row.resource_id == requested.supplier_resource_id }
    assert_equal "Quantity not tracked", cabin.status_label
    assert_nil tracked.blockers.find { |row| row.code == :opening_authority_incomplete }

    unknown = SupplierArrangementActivationReadiness::Blocker.new(
      track: :structure, code: :items_missing, path: "items", message: "Add at least one Arrangement Item."
    )
    real = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @setup[:arrangement], version: @setup[:version].reload
    ).call
    replaced = SupplierArrangementActivationReadiness::Result.new(
      version: real.version,
      blockers: [ unknown ],
      cost_selections: real.cost_selections
    )
    readiness = Object.new
    readiness.define_singleton_method(:call) { replaced }
    reviewed = with_constructor(SupplierArrangementActivationReadiness, readiness) { compile }
    row = reviewed.blockers.sole
    assert_equal false, row.known?
    assert_equal :advanced, row.destination
    assert_equal "Add at least one Arrangement Item.", row.message
    assert_equal false, reviewed.cruise_post_allowed?
  end

  test "presentation mode keeps the same activation conclusion" do
    assert_same_activation_conclusion

    prepare_post_eligible!
    assert_same_activation_conclusion

    add_estimate_source!
    assert_same_activation_conclusion
  end

  private

  def assert_same_activation_conclusion
    full = compile
    plain = compile(presentation: false)

    assert_equal full.cruise_post_allowed?, plain.cruise_post_allowed?
    assert_equal full.readiness_ready?, plain.readiness_ready?
    assert_equal full.activated?, plain.activated?
    assert_equal full.blockers.map(&:code), plain.blockers.map(&:code)
    assert_equal full.unsupported_reasons, plain.unsupported_reasons
  end

  def with_constructor(klass, replacement)
    singleton = klass.singleton_class
    singleton.alias_method :new_without_review_stub, :new
    singleton.define_method(:new) { |**| replacement }
    yield
  ensure
    singleton.alias_method :new, :new_without_review_stub
    singleton.remove_method :new_without_review_stub
  end

  def with_unrepresented_trigger
    trigger = Object.new
    trigger.define_singleton_method(:id) { SecureRandom.uuid }
    trigger.define_singleton_method(:description) { "Custom commitment" }
    trigger.define_singleton_method(:trigger_kind) { "custom" }
    trigger.define_singleton_method(:authority_shape) { "fixed_quantity" }
    trigger.define_singleton_method(:arrangement_confirmation?) { false }
    SupplierArrangementVersion.class_eval do
      alias_method :triggers_without_unrepresented_test, :supplier_commitment_trigger_definitions
      define_method(:supplier_commitment_trigger_definitions) do
        UnrepresentedTriggerProxy.new(triggers_without_unrepresented_test, [ trigger ])
      end
    end
    yield
  ensure
    SupplierArrangementVersion.class_eval do
      alias_method :supplier_commitment_trigger_definitions, :triggers_without_unrepresented_test
      remove_method :triggers_without_unrepresented_test
    end
  end

  class UnrepresentedTriggerProxy
    def initialize(real, rows)
      @real = real
      @rows = rows
    end

    def includes(...) = @real.includes(...)
    def order(*) = UnrepresentedTriggerScope.new(@rows)
  end

  class UnrepresentedTriggerScope
    def initialize(rows)
      @rows = rows
    end

    def order(*) = self
    def map(...) = @rows.map(...)
    def none? = @rows.none?
    def each(...) = @rows.each(...)
  end

  def compile(presentation: true)
    CompileCruiseActivationReview.new(
      agency: @agency,
      arrangement: @setup[:arrangement],
      version: @setup[:version].reload,
      presentation: presentation
    ).call
  end

  def prepare_post_eligible!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    satisfy_cruise_activation_gate!(
      agency: @agency,
      actor: @staff,
      arrangement: @setup[:arrangement],
      version: @setup[:version].reload
    )
  end

  def add_estimate_source!
    version = @setup[:version].reload
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @setup[:arrangement],
      supplier_arrangement_version: version,
      arrangement_item: @setup[:item],
      charging_supplier: @contractor,
      label: "Planning estimate",
      position: version.supplier_cost_sources.maximum(:position).to_i + 1
    )
    source.supplier_cost_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @setup[:arrangement],
      supplier_arrangement_version: version,
      stage: "estimate",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Planning only",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:estimate",
      readiness_provenance: "Planning"
    )
  end

  def create_sailing!
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: provider.id },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    { arrangement: arrangement, version: arrangement.versions.sole, item: arrangement.arrangement_items.sole }
  end

  def add_cabin!(setup, name:, code:, inventory_mode:, quantity: nil)
    pool_attributes = {
      inventory_mode: inventory_mode,
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin terms"
    }
    pool_attributes[:proposed_opening_quantity] = quantity if quantity
    result = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: setup[:arrangement],
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
      pool_attributes: pool_attributes,
      version_lock_version: setup[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    result.record.pool
  end
end
