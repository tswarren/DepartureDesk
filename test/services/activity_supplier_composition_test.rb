# frozen_string_literal: true

require "test_helper"

class ActivitySupplierCompositionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Port Promotions" },
      categories: [ "activity_attraction" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Smith Family Reunion", starts_on: Date.new(2027, 11, 6), ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York", operating_currency: "USD",
        responsible_office_id: @office.id, responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Port Promotions", contracting_supplier_id: @supplier.id }
    ).call.record
  end

  test "staff records island sightseeing without a payable quantity" do
    item = save_activity(name: "Island Sightseeing", expected_persons: 4)
    version = draft

    assert_equal "activity_attraction", version.arrangement_item_definitions.find_by!(arrangement_item: item).category
    occurrence = version.service_occurrence_definitions.find_by!(arrangement_item: item)
    assert_equal Date.new(2027, 11, 8), occurrence.starts_on
    assert_equal "America/Nassau", occurrence.time_zone
    assert_equal "CocoCay, Bahamas", occurrence.origin_name
    assert_equal "CocoCay, Bahamas", occurrence.destination_name
    assert_nil version.supplier_resource_definitions.find_by!(arrangement_item: item).maximum_occupancy
    pool = version.capacity_pool_definitions.find_by!(arrangement_item: item)
    assert_equal 40, pool.proposed_opening_quantity
    assert_equal "traveler_positions", pool.capacity_pool.measurement_basis
    assert_equal "participant spaces", pool.unit_label

    assert_equal 20_000, forecast_total
    save_activity(item:, expected_persons: 5)
    assert_equal 25_000, forecast_total
    save_activity(item:, expected_persons: 20)
    assert_equal 100_000, forecast_total
    save_activity(item:, expected_persons: 40)
    assert_equal 200_000, forecast_total
    save_activity(item:, expected_persons: 4)
    assert_equal 20_000, forecast_total
    assert_equal 40, draft.capacity_pool_definitions.find_by!(arrangement_item: item).proposed_opening_quantity
    assert_empty draft.supplier_cost_components.where(calculation_kind: "minimum_quantity_shortfall")

    threshold = draft.supplier_operating_threshold_definitions.find_by!(arrangement_item: item)
    assert_equal 5, threshold.minimum_quantity
    assert_equal "supplier_decision", threshold.below_threshold_authority
    review = ActivityAgreementShape.deadline(draft, item, "other")
    assert_equal "informational", review.kind
    assert_equal "Minimum-enrollment review", review.other_label
    assert_equal "2027-11-01", review.rule_parameters["date"]
    assert ActivityAgreementShape.deadline(draft, item, "final_count_due")
    assert ActivityAgreementShape.deadline(draft, item, "cancellation_cutoff")
    payment = draft.supplier_payment_requirement_definitions.find_by!(arrangement_item: item)
    assert_equal "authoritative_quantity_unavailable", payment.quantity_status
    assert_equal Date.new(2027, 11, 1), payment.due_on
    assert_not payment.has_attribute?(:amount_minor_units)
    assert_empty draft.supplier_amount_due_definitions
    assert_not SupplierDeadlineDefinition::DEADLINE_TYPES.include?("payment_due")
    inclusion = draft.supplier_agreement_references.find_by!(arrangement_item: item, kind: "rate_inclusions")
    assert_includes inclusion.governing_wording, "Gratuities are not included"
    assert draft.supplier_agreement_references.exists?(arrangement_item: item, kind: "cancellation")

    sibling = save_activity(name: "Harbor sail", expected_persons: 4)
    assert_raises(AgencyCommand::Error) do
      save_activity(item:, name: "Renamed sightseeing", ends_at_local: "08:00")
    end
    assert_equal "Island Sightseeing", draft.arrangement_item_definitions.find_by!(arrangement_item: item).name
    assert_equal "Harbor sail", draft.arrangement_item_definitions.find_by!(arrangement_item: sibling).name

    unfinished = CreateArrangementItemSetup.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: draft.lock_version, idempotency_key: SecureRandom.uuid,
      item_attributes: { name: "Unfinished", category: "activity_attraction", default_service_provider_id: @supplier.id }
    ).call.record.item
    assert_raises(AgencyCommand::Error) { confirm! }
    RemoveArrangementItem.new(
      agency: @agency, actor: @admin, item: unfinished, version_lock_version: draft.lock_version
    ).call

    lodging = CreateArrangementItemSetup.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: draft.lock_version, idempotency_key: SecureRandom.uuid,
      item_attributes: { name: "Hotel night", category: "lodging", default_service_provider_id: @supplier.id }
    ).call.record.item
    error = assert_raises(AgencyCommand::Error) { confirm! }
    assert_equal ActivityAgreementShape::ADVANCED, error.message
    RemoveArrangementItem.new(
      agency: @agency, actor: @admin, item: lodging, version_lock_version: draft.lock_version
    ).call

    confirm!
    assert_raises(AgencyCommand::Error) { save_activity(item:, name: "Changed after confirmation") }
    assert_equal "Island Sightseeing", draft.arrangement_item_definitions.find_by!(arrangement_item: item).name

    ActivateDeparture.new(
      agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    ActivateActivityAgreement.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: draft,
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: draft.lock_version
    ).call
    assert @arrangement.reload.active?

    rate_before = governing.supplier_cost_components.pick(:amount_minor_units)
    occurrence_id = item.service_occurrences.pick(:id)
    RecordActivityOperatingOutcome.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, item: item,
      outcome: "operate", evidence: "Port Promotions will operate with four travelers",
      occurred_on: "2027-11-01", observed_quantity: 4, idempotency_key: SecureRandom.uuid
    ).call
    assert_equal rate_before, governing.supplier_cost_components.pick(:amount_minor_units)
    assert_equal occurrence_id, item.service_occurrences.pick(:id)
    deadline = ActivityAgreementShape.deadline(governing, item, "final_count_due")
    RecordActivityFinalCount.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, item: item, idempotency_key: SecureRandom.uuid
    ).call
    assert_equal "2027-11-01", deadline.reload.rule_parameters["date"]

    CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: governing.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    successor = @arrangement.versions.find_by!(status: "draft")
    assert_equal item.id, successor.arrangement_item_definitions.find_by!(name: "Island Sightseeing").arrangement_item_id
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: successor.id)
    assert_equal 5_000, governing.supplier_cost_components.pick(:amount_minor_units)
    assert successor.supplier_operating_threshold_definitions.exists?(arrangement_item: item)
    assert_not SupplierOperatingThresholdOutcome.exists?(
      supplier_operating_threshold_definition_id: successor.supplier_operating_threshold_definitions.pick(:id)
    )
  end

  test "a cancel outcome does not cancel the occurrence and a draft threshold cannot take an outcome" do
    item = save_activity
    assert_raises(AgencyCommand::Error) do
      RecordActivityOperatingOutcome.new(
        agency: @agency, actor: @admin, arrangement: @arrangement, item: item,
        outcome: "cancel", evidence: "Too early", occurred_on: Date.current,
        observed_quantity: 4, idempotency_key: SecureRandom.uuid
      ).call
    end

    confirm!
    ActivateDeparture.new(
      agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    ActivateActivityAgreement.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: @arrangement.versions.find_by!(status: "draft"),
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @arrangement.versions.find_by!(status: "draft").lock_version
    ).call
    version = @arrangement.reload.governing_version
    item = version.arrangement_item_definitions.find_by!(name: "Island Sightseeing").arrangement_item
    RecordActivityOperatingOutcome.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, item: item,
      outcome: "cancel", evidence: "Port Promotions cancelled the activity",
      occurred_on: "2027-11-01", observed_quantity: 3, idempotency_key: SecureRandom.uuid
    ).call
    assert version.service_occurrence_definitions.exists?(arrangement_item: item, starts_on: Date.new(2027, 11, 8))
    assert_equal 5_000, version.supplier_cost_components.pick(:amount_minor_units)
  end

  private

  def save_activity(item: nil, **overrides)
    SaveActivity.new(
      agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, item: item,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Island Sightseeing", location: "CocoCay, Bahamas",
        starts_on: "2027-11-08", starts_at_local: "09:30", ends_at_local: "15:00",
        time_zone: "America/Nassau", participant_spaces: 40, rate_amount: "50.00",
        expected_persons: 4, minimum_quantity: 5, terms_on: "2027-11-01"
      }.merge(overrides)
    ).call
  end

  def confirm!
    RecordActivitySupplierConfirmation.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version: draft,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current, channel: "email",
        reference_note: "Port Promotions confirmed the activity",
        confirmed_without_identifier_reason: "No file number yet"
      }
    ).call
  end

  def draft
    @arrangement.versions.find_by!(status: "draft").reload
  end

  def governing
    @arrangement.reload.governing_version
  end

  def forecast_total
    EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version: draft
    ).call.totals.forecast_supplier_cost_minor_units
  end
end
