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

  test "an explicit empty cancellation list clears only the ladder" do
    record_readable_terms!
    allocated = @version.supplier_arrangement_cruise_term_definitions.find_by!(term_type: "allocated_cabin_deposit")
    card = @version.supplier_arrangement_cruise_term_definitions.find_by!(term_type: "card_restrictions")
    key = SecureRandom.uuid
    cleared = RecordCruiseAgreementTerms.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: key,
      cancellation_steps: []
    ).call

    assert_equal :created, cleared.status
    assert_equal @version, cleared.record
    assert_empty @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step")
    assert allocated.reload.persisted?
    assert card.reload.persisted?

    replay = RecordCruiseAgreementTerms.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: key,
      cancellation_steps: []
    ).call
    assert_equal :replayed, replay.status
    assert_equal @version, replay.record

    RecordCruiseAgreementTerms.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      card_restrictions: card.body
    ).call
    assert_empty @version.supplier_arrangement_cruise_term_definitions.where(term_type: "cancellation_step")
    assert_equal card.body, card.reload.body
  end

  test "a successor copies readable terms and leaves the confirmation behind" do
    record_readable_terms!
    prepare_original_activation!
    activate_departure!
    authorize_pool!(@version, @pool)
    activate_original!

    predecessor = @arrangement.reload.governing_version
    original_terms = predecessor.supplier_arrangement_cruise_term_definitions.order(:term_type, :position).to_a
    assert_equal %w[allocated_cabin_deposit cancellation_step cancellation_step card_restrictions],
      original_terms.map(&:term_type)

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: predecessor.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    copied = successor.supplier_arrangement_cruise_term_definitions.order(:term_type, :position).to_a
    assert_equal original_terms.map(&:term_type), copied.map(&:term_type)
    assert_equal original_terms.map(&:body), copied.map(&:body)
    assert_equal original_terms.map(&:id), copied.map(&:copied_from_id)
    assert_empty original_terms.map(&:id) & copied.map(&:id)
    assert_empty successor.supplier_arrangement_cruise_agreement_confirmations
    assert predecessor.supplier_arrangement_cruise_agreement_confirmations.exists?(current: true, status: "confirmed")
  end

  test "provisional and confirmed agreements require a group creation date" do
    provisional = assert_raises(AgencyCommand::Error) do
      RecordCruiseSupplierAgreement.new(
        **agreement_args("save_provisional").merge(group_creation_date: nil, group_reference: nil, contract_date: nil)
      ).call
    end
    assert_equal :invalid, provisional.code
    assert_match(/group creation date/i, provisional.message)

    confirmed = assert_raises(AgencyCommand::Error) do
      RecordCruiseSupplierAgreement.new(**agreement_args("confirm").merge(group_creation_date: nil)).call
    end
    assert_equal :invalid, confirmed.code

    saved = confirm!
    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangementCruiseAgreementConfirmation.transaction(requires_new: true) do
        saved.update_columns(group_creation_date: nil)
      end
    end
    assert_match(/cruise_agreement_confirmations_status_shape/i, error.message)
    assert_equal Date.new(2026, 9, 13), saved.reload.group_creation_date
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

  test "deposit due mismatch compares only the initial cruise deposit" do
    confirm!
    create_initial_deposit!(date: "2026-10-13")
    create_other_deposit!(date: "2026-09-01", description: "Earlier hold")
    create_other_deposit!(date: "2026-12-01", description: "Later hold")

    assert_equal [ Date.new(2026, 10, 13) ], CruiseInitialDepositDueDate.initial_deposit_due_dates(@version.reload)
    assert_not initial_deposit_mismatches?

    initial = @version.supplier_deposit_requirement_definitions.find_by!(description: "Initial deposit")
    initial.update!(rule_parameters: { "date" => "2026-10-20" })
    assert_equal [ Date.new(2026, 10, 20) ], CruiseInitialDepositDueDate.initial_deposit_due_dates(@version.reload)
    assert initial_deposit_mismatches?
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
      group_creation_date: "2026-09-13",
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

  def record_readable_terms!
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
  end

  def create_initial_deposit!(date:)
    pool_definition = @version.capacity_pool_definitions.find_by!(capacity_pool: @pool)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @actor,
      version: @version,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        currency: "USD",
        rate_minor_units: 5_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ {
          capacity_pool_id: @pool.id,
          arrangement_item_id: pool_definition.arrangement_item_id,
          service_occurrence_id: pool_definition.service_occurrence_id,
          supplier_resource_id: pool_definition.supplier_resource_id
        } ]
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def create_other_deposit!(date:, description:)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @actor,
      version: @version,
      attributes: {
        description: description,
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: 10_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ { arrangement_item_id: @item.id } ]
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def initial_deposit_mismatches?
    creation_date = @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true).group_creation_date
    CruiseInitialDepositDueDate.initial_deposit_due_dates(@version).any? { |saved_on|
      CruiseInitialDepositDueDate.mismatch?(saved_on: saved_on, group_creation_date: creation_date)
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
