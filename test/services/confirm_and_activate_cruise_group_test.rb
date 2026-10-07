# frozen_string_literal: true

require "test_helper"

class ConfirmAndActivateCruiseGroupTest < ActiveSupport::TestCase
  include CapacityGraphHelper
  include CruiseActivationGateHelper
  include ApplicationHelper

  Cruise = Struct.new(
    :departure, :contractor, :arrangement, :version, :pool, :resource,
    keyword_init: true
  )

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
  end

  test "proof type alone records omitted confirmation fields and activation authority" do
    cruise = build_confirmable_cruise!
    result = activate!(cruise)

    assert_equal :created, result.status
    confirmation = cruise.version.supplier_confirmations.sole
    assert_equal "supplier_confirmation", confirmation.evidence_kind
    assert_nil confirmation.evidence_on
    assert_nil confirmation.channel
    assert_nil confirmation.reference_note
    assert_nil confirmation.confirmed_without_identifier_reason
    assert confirmation.recorded_at.present?
    assert_empty confirmation.supplier_issued_identifiers

    definition = cruise.version.supplier_cost_definitions.where(stage: "contracted").sole
    assert definition.contract_review_current?
    assert_equal ConfirmAndActivateCruiseGroup::PROVENANCE, definition.contract_review_provenance

    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    assert_equal "supplier_confirmation", pool_definition.evidence_kind
    assert_equal Date.new(2026, 9, 13), pool_definition.evidence_on
    assert_equal "agreement_contract_date", pool_definition.evidence_on_origin
    assert_equal ConfirmAndActivateCruiseGroup::ATTESTATION_NOTE, pool_definition.evidence_reference_note
    assert_equal "activation_attestation", pool_definition.evidence_reference_origin
    assert_equal confirmation, pool_definition.opening_authority_confirmation

    event = cruise.pool.capacity_events.sole
    assert_equal "agreement_contract_date", event.evidence_on_origin
    assert_equal "activation_attestation", event.evidence_reference_origin
    label = capacity_evidence_history_label(event)
    assert_match "Agreement contract date", label
    assert_match "System attestation", label
    assert cruise.version.reload.activated?
  end

  test "a long supplier note stays on the confirmation and the opening note stays bounded" do
    cruise = build_confirmable_cruise!
    note = "N" * SupplierConfirmation::TEXT_LIMIT
    activate!(cruise, supplier_reference: "1119999", evidence: {
      evidence_kind: "supplier_confirmation",
      reference_note: note
    })

    confirmation = cruise.version.supplier_confirmations.sole
    assert_equal note, confirmation.reference_note
    assert_equal "1119999", confirmation.supplier_issued_identifiers.sole.display_value
    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    assert_operator pool_definition.evidence_reference_note.length, :<=, CapacityPoolDefinition::EVIDENCE_REFERENCE_NOTE_LIMIT
    assert_equal "1119999", pool_definition.evidence_reference_note
    assert_equal "supplier", pool_definition.evidence_reference_origin
  end

  test "the activation review shows credits applicability and commission meaning" do
    cruise = build_confirmable_cruise!(rates: :none)
    record_rates!(cruise, cruise.resource, cells: {
      "base_fare:first_second" => "1500.00",
      "base_fare:additional" => "500.00",
      "base_fare:single_supplement" => "1500.00",
      "discount:first_second" => "150.00"
    }, commission: {
      method: "percentage",
      percentage: "10",
      add_cells: %w[base_fare:first_second],
      subtract_cells: %w[discount:first_second]
    })
    label = activation_review(cruise).cabins.sole.charges_label
    assert_match "Base Fare", label
    assert_match "First/Second", label
    assert_match "$1,500", label
    assert_match "Credit", label
    assert_match "Discount", label
    assert_match "Expected commission", label
    assert_match "10%", label

    plain = build_confirmable_cruise!
    plain_label = activation_review(plain).cabins.sole.charges_label
    assert_match "Commission: not recorded", plain_label

    noncommissionable = build_confirmable_cruise!(rates: :none)
    record_rates!(noncommissionable, noncommissionable.resource, commission: { method: "none" })
    assert noncommissionable.version.supplier_cost_definitions.find_by!(stage: "contracted").noncommissionable?
    assert_match "Commission: noncommissionable", activation_review(noncommissionable).cabins.sole.charges_label
  end

  test "a supplied reference is a group number and a cleared reference needs no absence reason" do
    cruise = build_confirmable_cruise!
    activate!(cruise, supplier_reference: "1119999", evidence: {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-10-01",
      reference_note: "Portal note"
    })

    identifier = cruise.version.supplier_confirmations.sole.supplier_issued_identifiers.sole
    assert_equal "group_number", identifier.identifier_type
    assert_equal "1119999", identifier.display_value
    assert_equal cruise.contractor.display_name_for_directory, identifier.issuer_context
    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    assert_equal Date.new(2026, 10, 1), pool_definition.evidence_on
    assert_equal "supplied", pool_definition.evidence_on_origin
    assert_equal "supplier", pool_definition.evidence_reference_origin
    assert_equal "1119999\nPortal note", pool_definition.evidence_reference_note
    label = capacity_evidence_history_label(cruise.pool.capacity_events.sole)
    assert_no_match "Agreement contract date", label
    assert_no_match "System attestation", label
  end

  test "an existing relaxed confirmation can be reused only by cruise activation" do
    cruise = build_confirmable_cruise!(reviewed: true, usable_rates: false, evidenced: true)
    confirmation = RecordSupplierConfirmationEvidence.new(
      agency: @agency,
      actor: @staff,
      arrangement: cruise.arrangement,
      version: cruise.version,
      recorded_at: Time.current,
      evidence_attributes: { evidence_kind: "supplier_portal" },
      evidence_policy: :cruise_activation
    ).call.record

    error = assert_no_difference "SupplierArrangementActivation.count" do
      assert_raises(AgencyCommand::Error) do
        ActivateSupplierArrangementVersion.new(
          agency: @agency,
          actor: @staff,
          arrangement: cruise.arrangement,
          version: cruise.version,
          arrangement_lock_version: cruise.arrangement.lock_version,
          version_lock_version: cruise.version.lock_version,
          idempotency_key: SecureRandom.uuid,
          existing_confirmation_id: confirmation.id,
          cost_source_coverage_acknowledged: true,
          provisional_costs_acknowledged: false,
          commitment_trigger_coverage_acknowledged: true
        ).call
      end
    end
    assert_match "does not meet the Supplier evidence requirements", error.message
    assert cruise.version.reload.draft?

    activate!(cruise, existing_confirmation_id: confirmation.id, evidence: {})
    activation = cruise.version.reload.supplier_arrangement_activation
    assert_equal confirmation, activation.supplier_confirmation
    assert_equal 1, SupplierConfirmation.where(supplier_arrangement_version: cruise.version).count
    assert_equal "contract", cruise.pool.capacity_events.sole.evidence_kind
  end

  test "usable unreviewed rates and quantities are ready to review and activation records them" do
    cruise = build_confirmable_cruise!
    navigation = CompileCruiseSetupNavigation.new(
      agency: @agency, arrangement: cruise.arrangement,
      shape: DetectCruiseArrangementShape.new(agency: @agency, arrangement: cruise.arrangement).call
    ).call
    statuses = navigation.areas.index_by(&:key)
    assert_equal "Complete", statuses[:cabins].status
    assert_equal "Complete", statuses[:rates].status
    assert_equal "Ready to review", statuses[:review].status
    assert navigation.attention_items.none? { |item|
      %i[opening_authority_incomplete cruise_contracted_rates_missing].include?(item.code)
    }

    activate!(cruise, evidence: { evidence_kind: "contract" })
    assert cruise.version.supplier_cost_definitions.where(stage: "contracted").sole.contract_review_current?
    assert cruise.pool.capacity_events.sole.evidence_kind == "contract"
  end

  test "a missing quantity or unusable rate or unconfirmed agreement writes nothing" do
    missing_quantity = build_confirmable_cruise!
    missing_quantity.version.capacity_pool_definitions.find_by!(capacity_pool: missing_quantity.pool)
      .update!(proposed_opening_quantity: nil)
    assert_no_activation!(missing_quantity)

    unusable = build_confirmable_cruise!
    unusable.version.supplier_cost_definitions.where(stage: "contracted").sole
      .supplier_cost_components.where(calculation_kind: "unit_rate").update_all(amount_minor_units: 0)
    navigation = CompileCruiseSetupNavigation.new(
      agency: @agency, arrangement: unusable.arrangement,
      shape: DetectCruiseArrangementShape.new(agency: @agency, arrangement: unusable.arrangement).call
    ).call
    assert_equal "Needs attention", navigation.areas.find { |area| area.key == :rates }.status
    review = CompileCruiseActivationReview.new(
      agency: @agency, arrangement: unusable.arrangement, version: unusable.version
    ).call
    assert_equal "Needs attention", CompileCruiseSetupNavigation.new(
      agency: @agency, arrangement: unusable.arrangement,
      shape: DetectCruiseArrangementShape.new(agency: @agency, arrangement: unusable.arrangement).call
    ).call.areas.find { |area| area.key == :review }.status
    assert_not review.activation_confirmable?
    assert_no_activation!(unusable)

    unconfirmed = build_confirmable_cruise!(confirm_agreement: false)
    assert_no_activation!(unconfirmed)
  end

  test "an override followed by invalid proof leaves no authority or audit" do
    cruise = build_confirmable_cruise!
    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    assert_no_difference [ "AuditEvent.count", "SupplierConfirmation.count" ] do
      assert_raises(AgencyCommand::Error) do
        activate!(
          cruise,
          actor: @admin,
          evidence: { evidence_kind: "other" },
          opening_overrides: { pool_definition.id => "Ordinary proof does not apply" }
        )
      end
    end
    assert_not pool_definition.reload.override?
    assert_nil pool_definition.evidence_kind
    assert cruise.version.reload.draft?
  end

  test "a stale submission and an unrelated pool write nothing" do
    cruise = build_confirmable_cruise!
    stale_lock = cruise.version.lock_version
    cruise.version.touch
    assert_no_difference "SupplierConfirmation.count" do
      error = assert_raises(AgencyCommand::Error) do
        activate!(cruise, version_lock_version: stale_lock)
      end
      assert_equal :conflict, error.code
    end

    assert_no_difference "SupplierConfirmation.count" do
      assert_raises(AgencyCommand::Error) do
        activate!(cruise, opening_overrides: { SecureRandom.uuid => "Not this cabin" }, actor: @admin)
      end
    end
    assert cruise.version.reload.draft?
  end

  test "activation failure rolls back review stamps and opening authority" do
    cruise = build_confirmable_cruise!
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: cruise.departure,
      supplier_arrangement: cruise.arrangement,
      supplier_arrangement_version: cruise.version,
      committed_supplier: cruise.contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "confirmed_quantity",
      description: "Retain cabins",
      quantity_basis: "resource_units",
      position: 1
    )
    assert_no_difference [ "AuditEvent.count", "SupplierConfirmation.count", "SupplierArrangementActivation.count" ] do
      assert_raises(AgencyCommand::Error) do
        activate!(cruise)
      end
    end
    definition = cruise.version.supplier_cost_definitions.where(stage: "contracted").sole
    assert_not definition.reload.contract_review_current?
    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    assert_nil pool_definition.evidence_kind
    assert cruise.version.reload.draft?
  end

  test "every booking proof type establishes opening authority and other keeps its description" do
    SupplierConfirmation::BOOKING_EVIDENCE_KINDS.each do |kind|
      cruise = build_confirmable_cruise!
      evidence = { evidence_kind: kind }
      evidence[:other_evidence_label] = "Phone call" if kind == "other"
      activate!(cruise, evidence: evidence)
      confirmation = cruise.version.supplier_confirmations.sole
      event = cruise.pool.capacity_events.sole
      assert_equal kind, event.evidence_kind
      assert_equal confirmation, cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool).opening_authority_confirmation
      if kind == "other"
        assert_equal "Phone call", confirmation.other_evidence_label
        assert_match "Phone call", capacity_evidence_history_label(event)
      end
    end
  end

  test "a successful retry replays and a changed proof conflicts" do
    cruise = build_confirmable_cruise!
    key = SecureRandom.uuid
    locks = {
      arrangement_lock_version: cruise.arrangement.lock_version,
      version_lock_version: cruise.version.lock_version
    }
    first = activate!(cruise, idempotency_key: key, **locks)
    assert_no_difference [ "SupplierConfirmation.count", "AuditEvent.count", "SupplierArrangementActivation.count" ] do
      replay = activate!(cruise, idempotency_key: key, **locks)
      assert_equal :replayed, replay.status
      assert_equal first.record, replay.record
    end

    error = assert_raises(AgencyCommand::Error) do
      activate!(cruise, idempotency_key: key, evidence: { evidence_kind: "verbal_confirmation" }, **locks)
    end
    assert_equal "That idempotency key was already used for different input.", error.message
  end

  test "an on-request category is not given opening authority" do
    cruise = build_confirmable_cruise!
    on_request = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: cruise.arrangement,
      resource_attributes: { name: "Guarantee", supplier_code: "G1", maximum_occupancy: 2 },
      pool_attributes: { inventory_mode: "on_request" },
      version_lock_version: cruise.version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    cruise.version.reload
    record_rates!(cruise, on_request.record.resource)
    activate!(cruise, version_lock_version: cruise.version.lock_version, arrangement_lock_version: cruise.arrangement.reload.lock_version)

    definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: on_request.record.pool)
    assert_nil definition.evidence_kind
    assert_not definition.override?
    assert_nil definition.proposed_opening_quantity
  end

  test "generic confirmation still requires the strict fields" do
    cruise = build_confirmable_cruise!(reviewed: true, usable_rates: false, evidenced: true)
    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierConfirmationEvidence.new(
        agency: @agency,
        actor: @staff,
        arrangement: cruise.arrangement,
        version: cruise.version,
        recorded_at: Time.current,
        evidence_attributes: { evidence_kind: "supplier_confirmation" }
      ).call
    end
    assert_match "complete Supplier confirmation evidence", error.message

    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierConfirmationEvidence.new(
        agency: @agency,
        actor: @staff,
        arrangement: cruise.arrangement,
        version: cruise.version,
        recorded_at: Time.current,
        evidence_attributes: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Approved"
        }
      ).call
    end
    assert_match "Supplier identifier", error.message
  end

  test "administrator override records no supplier evidence on that cabin" do
    cruise = build_confirmable_cruise!
    pool_definition = cruise.version.capacity_pool_definitions.find_by!(capacity_pool: cruise.pool)
    error = assert_no_difference "SupplierConfirmation.count" do
      assert_raises(AgencyCommand::Error) do
        activate!(cruise, opening_overrides: { pool_definition.id => "Desk confirmed the block" })
      end
    end
    assert_match "not allowed", error.message

    activate!(
      cruise,
      actor: @admin,
      opening_overrides: { pool_definition.id => "Desk confirmed the block" }
    )
    pool_definition.reload
    assert pool_definition.override?
    assert_equal "Desk confirmed the block", pool_definition.override_reason
    assert_nil pool_definition.evidence_kind
    assert_nil pool_definition.evidence_on_origin
    event = cruise.pool.capacity_events.sole
    assert event.override?
    assert_nil event.evidence_on_origin
  end

  private

  def activate!(cruise, actor: @staff, evidence: { evidence_kind: "supplier_confirmation" }, **overrides)
    ConfirmAndActivateCruiseGroup.new(
      agency: @agency,
      actor: actor,
      arrangement: cruise.arrangement,
      version: cruise.version.reload,
      idempotency_key: overrides.fetch(:idempotency_key, SecureRandom.uuid),
      terms_acknowledged: true,
      arrangement_lock_version: overrides.fetch(:arrangement_lock_version, cruise.arrangement.reload.lock_version),
      version_lock_version: overrides.fetch(:version_lock_version, cruise.version.lock_version),
      evidence_attributes: evidence,
      supplier_reference: overrides[:supplier_reference],
      existing_confirmation_id: overrides[:existing_confirmation_id],
      opening_overrides: overrides.fetch(:opening_overrides, {})
    ).call
  end

  def assert_no_activation!(cruise)
    assert_no_difference [ "SupplierConfirmation.count", "AuditEvent.count", "SupplierArrangementActivation.count" ] do
      assert_raises(AgencyCommand::Error) { activate!(cruise) }
    end
    assert cruise.version.reload.draft?
  end

  def build_confirmable_cruise!(quantity: 8, confirm_agreement: true, usable_rates: true, reviewed: false, evidenced: false, rates: nil)
    contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: contractor.id,
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
    version = arrangement.versions.sole
    pool_attributes = { inventory_mode: "block" }
    pool_attributes[:proposed_opening_quantity] = quantity if quantity
    if evidenced
      pool_attributes.merge!(
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      )
    end
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: pool_attributes,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    version.reload
    cruise = Cruise.new(
      departure: departure, contractor: contractor, arrangement: arrangement,
      version: version, pool: cabin.record.pool, resource: cabin.record.resource
    )
    if confirm_agreement
      RecordCruiseSupplierAgreement.new(
        agency: @agency,
        actor: @staff,
        arrangement: arrangement,
        intent: "confirm",
        version_lock_version: version.lock_version,
        idempotency_key: SecureRandom.uuid,
        group_reference: "1119999",
        group_creation_date: "2026-09-01",
        contract_date: "2026-09-13"
      ).call
      version.reload
    end
    rate_mode = rates || (reviewed ? :reviewed : usable_rates ? :usable : :incomplete)
    if rate_mode == :reviewed
      satisfy_cruise_activation_gate!(agency: @agency, actor: @staff, arrangement: arrangement, version: version.reload)
    elsif rate_mode == :usable
      record_rates!(cruise, cabin.record.resource)
    elsif rate_mode == :none
      nil
    else
      source = version.supplier_cost_sources.create!(
        agency: @agency, departure: departure, supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        arrangement_item: arrangement.arrangement_items.sole,
        service_occurrence: arrangement.arrangement_items.sole.service_occurrences.sole,
        supplier_resource: cabin.record.resource,
        charging_supplier: contractor,
        label: "Incomplete contracted rate",
        position: 1
      )
      source.supplier_cost_definitions.create!(
        agency: @agency, departure: departure, supplier_arrangement: arrangement,
        supplier_arrangement_version: version, stage: "contracted", status: "working",
        mode: "calculated", currency: departure.operating_currency
      )
    end
    cruise.version = version.reload
    cruise
  end

  def activation_review(cruise)
    CompileCruiseActivationReview.new(
      agency: @agency, arrangement: cruise.arrangement, version: cruise.version.reload
    ).call
  end

  def record_rates!(cruise, resource, cells: nil, commission: nil)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: cruise.arrangement,
      resource: resource,
      profiles: [
        { family: "first_second", key: "first_second" },
        { family: "additional", key: "additional" },
        { family: "single_supplement", key: "single_supplement" }
      ],
      cells: cells || {
        "base_fare:first_second" => "1500.00",
        "base_fare:additional" => "500.00",
        "base_fare:single_supplement" => "1500.00"
      },
      commission: commission || { method: "not_provided" },
      stage: "estimate",
      version_lock_version: cruise.version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    RecordCruiseContractedRates.new(
      agency: @agency,
      actor: @staff,
      arrangement: cruise.arrangement,
      resource: resource,
      version_lock_version: cruise.version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    cruise.version.reload
  end
end
