# frozen_string_literal: true

require "test_helper"

class CruiseReworkTest < ActiveSupport::TestCase
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
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @pool = cabin.record.pool
    @version.reload
  end

  test "cruise activation requires confirmation and ready contracted cabin rates" do
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version
    ).call
    assert readiness.blockers.any? { |blocker| blocker.code == :cruise_agreement_unconfirmed }
    assert readiness.blockers.any? { |blocker| blocker.code == :cruise_contracted_rates_missing }

    confirm!
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    assert readiness.blockers.none? { |blocker| blocker.code == :cruise_agreement_unconfirmed }
    assert readiness.blockers.any? { |blocker| blocker.code == :cruise_contracted_rates_missing }
  end

  test "confirmation correction keeps the original confirmation" do
    saved = RecordCruiseSupplierAgreement.new(
      **agreement_args("save_provisional").merge(
        group_creation_date: "2026-09-13",
        group_reference: nil,
        contract_date: nil
      )
    ).call
    assert_equal "provisional", saved.record.status
    assert_nil saved.record.group_reference

    confirmed = confirm!
    assert_equal "1119999", confirmed.group_reference
    assert_equal Date.new(2026, 9, 13), confirmed.contract_date

    error = assert_raises(AgencyCommand::Error) do
      RecordCruiseSupplierAgreement.new(**agreement_args("save_provisional").merge(group_reference: "changed")).call
    end
    assert_equal :invalid_state, error.code

    corrected = RecordCruiseSupplierAgreement.new(
      **agreement_args("correct").merge(group_reference: "1119998", contract_date: "2026-09-14")
    ).call.record
    assert_equal "1119998", corrected.group_reference
    assert_equal confirmed.id, corrected.corrects_id
    confirmed.reload
    assert_equal "1119999", confirmed.group_reference
    assert_not confirmed.current?
    assert corrected.current?
  end

  test "readable terms do not create deposit requirements" do
    before = SupplierDepositRequirementDefinition.count
    RecordCruiseAgreementTerms.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      allocated_cabin_deposit: {
        amount_minor_units: 50_000,
        credit_minor_units: 5_000,
        currency: "USD",
        body: "$500 per allocated stateroom with a $50 credit"
      },
      card_restrictions: "Final payment is not accepted on the restricted cards.",
      cancellation_steps: [
        { days_before_departure: 90, body: "Deposit retained" },
        { days_before_departure: 30, body: "Fare retained" }
      ]
    ).call

    assert_equal before, SupplierDepositRequirementDefinition.count
    terms = @version.supplier_arrangement_cruise_term_definitions.order(:term_type, :position)
    assert_equal %w[allocated_cabin_deposit cancellation_step cancellation_step card_restrictions],
      terms.map(&:term_type)
    assert_equal [ 90, 30 ], terms.select(&:cancellation_step?).map(&:days_before_departure)
  end

  test "a saved deposit due date stays put when the group creation date changes" do
    assert_equal Date.new(2026, 10, 13), CruiseInitialDepositDueDate.suggested_on(Date.new(2026, 9, 13))
    assert CruiseInitialDepositDueDate.mismatch?(
      saved_on: Date.new(2026, 10, 13),
      group_creation_date: Date.new(2026, 9, 1)
    )
    assert_not CruiseInitialDepositDueDate.mismatch?(
      saved_on: Date.new(2026, 10, 13),
      group_creation_date: Date.new(2026, 9, 13)
    )
  end

  test "same-terms increase records 200 dollars and leaves the original deposit" do
    graph = build_activated_established_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @provider,
      actor: @actor,
      recorded_at: Time.zone.parse("2026-09-13 12:00:00 UTC")
    )
    original_ids = graph[:version].supplier_deposit_requirement_definitions.pluck(:id)

    result = RecordCruiseSameTermsCapacityIncrease.new(
      agency: @agency,
      actor: @actor,
      arrangement: graph[:arrangement],
      pool_id: graph[:pool].id,
      quantity: 4,
      rate_minor_units: 5_000,
      evidence: {
        evidence_kind: "supplier_confirmation",
        evidence_on: "2026-10-01",
        evidence_reference_note: "Supplier added four O1 cabins"
      },
      idempotency_key: "same-terms-o1"
    ).call

    requirement = result.record
    assert_equal 4, requirement.quantity
    assert_equal 5_000, requirement.rate_minor_units
    assert_equal 20_000, requirement.amount_minor_units
    assert_equal "increased", requirement.capacity_event.event_type
    assert_equal original_ids, graph[:version].supplier_deposit_requirement_definitions.pluck(:id)
  end

  test "supplemental block keeps O1 and cannot activate until its own gates are satisfied" do
    prepare_original_activation!
    activate_departure!
    authorize_pool!(@version, @pool)
    @version.reload
    offer = ConnectCruiseServiceOffer.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new",
        title: "Oceanview",
        supplier_arrangement_version_id: @version.id,
        use_tentative_draft: true,
        arrangement_lock_version: @version.reload.lock_version,
        arrangement_item_id: @item.id,
        supplier_resource_ids: [ @resource.id ]
      }
    ).call.record
    choice_before = offer.editable_draft_version.choice_options.sole.attributes.slice(
      "id", "client_rate_category_key", "price_effect_minor_units"
    )
    binding_ids = offer.editable_draft_version.source_bindings.pluck(:supplier_resource_id, :supplier_arrangement_version_id)

    activate_original!
    original = @arrangement.reload.governing_version
    assert_equal @version.id, original.id

    created = CreateCruiseSupplementalBlock.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: original.lock_version,
      idempotency_key: "supplemental-o1",
      maximum_occupancy: 3,
      opening_quantity: 4
    ).call.record

    successor = created.version.reload
    definition = successor.supplier_resource_definitions.find_by!(supplier_resource_id: created.resource.id)
    assert_equal "O1", definition.supplier_code
    assert_equal "Supplemental O1 block", definition.name
    assert_equal original.id, @arrangement.reload.governing_version_id
    assert successor.supplier_arrangement_cruise_agreement_confirmations.none?

    blocked = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: successor
    ).call
    assert blocked.blockers.any? { |blocker| blocker.code == :cruise_agreement_unconfirmed }
    assert blocked.blockers.any? { |blocker| blocker.code == :cruise_contracted_rates_missing }

    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-10-20",
      deposit_treatment: "No additional initial deposit for this block."
    ).call
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: successor.reload
    )
    authorize_pool!(successor, created.pool)
    add_trigger!(successor)
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version: successor,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: successor.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplemental block confirmed",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call

    assert_equal successor.id, @arrangement.reload.governing_version_id
    original.reload
    assert original.superseded?
    assert_equal "1119999", original.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true).group_reference
    offer.reload
    choice_after = offer.editable_draft_version.choice_options.sole.attributes.slice(
      "id", "client_rate_category_key", "price_effect_minor_units"
    )
    assert_equal choice_before, choice_after
    assert_equal binding_ids, offer.editable_draft_version.source_bindings.pluck(:supplier_resource_id, :supplier_arrangement_version_id)
  end

  private

  def agreement_args(intent)
    {
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      intent: intent,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-09-13",
      group_creation_date: "2026-09-13"
    }
  end

  def confirm!
    RecordCruiseSupplierAgreement.new(**agreement_args("confirm")).call.record
  end

  def prepare_original_activation!
    confirm!
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version.reload
    )
    add_trigger!(@version)
  end

  def activate_departure!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
  end

  def authorize_pool!(version, pool)
    version.capacity_pool_definitions.find_by!(capacity_pool: pool).update!(
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin block"
    )
  end

  def activate_original!
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version: @version,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call
  end

  def add_trigger!(version)
    return if version.supplier_commitment_trigger_definitions.exists?

    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )
  end
end
