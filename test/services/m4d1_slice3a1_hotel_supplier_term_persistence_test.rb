require "test_helper"

class M4d1Slice3a1HotelSupplierTermPersistenceTest < ActiveSupport::TestCase
  ORIGINAL = "Deposits are non-refundable."
  GOVERNING = "The Hotel refunds the agency on or before November 20, 2027, the amount actually paid toward the deposits minus the attrition shortfall."

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @contractor = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Term Hotel #{SecureRandom.hex(3)}" },
      categories: [ "lodging" ]
    ).call.record
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Harbor", last_name: "Desk", status: "active"
    )
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin, current_office: @office,
      attributes: {
        name: "Term departure #{SecureRandom.hex(3)}",
        starts_on: Date.new(2027, 11, 4), ends_on: Date.new(2027, 11, 6),
        time_zone: "America/New_York", operating_currency: "USD",
        responsible_office_id: @office.id, responsible_agency_user_id: @admin.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Term stay", contracting_supplier_id: @contractor.id, supplier_contact_id: @contact.id
      }
    ).call.record
    @version = @arrangement.versions.sole
    @item = CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Stay", category: "lodging", default_service_provider_id: @contractor.id }
    ).call.record
    definition = @version.arrangement_item_definitions.find_by!(arrangement_item: @item)
    SetItemCapacityManagement.new(
      agency: @agency, actor: @admin, definition: definition,
      capacity_management: "unmanaged", lock_version: definition.lock_version
    ).call
    @occurrence = CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: @item,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "November 4", starts_on: "2027-11-04", ends_on: "2027-11-04" }
    ).call.record
    @resource = CreateSupplierResource.new(
      agency: @agency, actor: @admin, item: @item,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Standard" }
    ).call.record
    @source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: @item.id, service_occurrence_id: @occurrence.id,
        supplier_resource_id: @resource.id, charging_supplier_id: @contractor.id, label: "Room"
      }
    ).call.record
    @definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: @source,
      source_lock_version: @source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    @deposit = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        amount_shape: "fixed_amount", fixed_amount_minor_units: 10_000, currency: "USD",
        rule_shape: "fixed_date", rule_parameters: { "date" => "2026-10-01" },
        precision: "date_only", time_zone: "America/New_York",
        coverage_links: [], cost_links: [], contributor_definition_ids: []
      }
    ).call.record
  end

  test "commission treatment stays distinct from a missing commission component" do
    assert_equal "unspecified", @definition.commission_treatment
    assert_equal 0, @definition.supplier_cost_components.where(economic_role: "expected_commission").count

    updated = SetSupplierCostCommissionTreatment.new(
      agency: @agency, actor: @admin, definition: @definition,
      commission_treatment: "noncommissionable", lock_version: @definition.lock_version
    ).call
    assert_equal :updated, updated.status
    assert_predicate updated.record, :noncommissionable?

    noop = SetSupplierCostCommissionTreatment.new(
      agency: @agency, actor: @admin, definition: updated.record,
      commission_treatment: "noncommissionable", lock_version: updated.record.lock_version
    ).call
    assert_equal :noop, noop.status

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierCostComponent.new(
        agency: @agency, actor: @admin, definition: updated.record.reload,
        definition_lock_version: updated.record.lock_version, idempotency_key: SecureRandom.uuid,
        attributes: {
          label: "Commission", economic_role: "expected_commission", calculation_kind: "unit_rate",
          amount_minor_units: 1_000, quantity_basis: "resource_nights", pass_through: false
        }
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_predicate @definition.reload, :noncommissionable?
  end

  test "derivation wording stays fixed when the rate changes and a mismatched deposit still saves" do
    reference = record_reference(kind: "deposit_derivation", governing_wording: DERIVATION).record
    assert_equal DERIVATION, reference.governing_wording
    assert_nil reference.original_wording
    assert_equal "Hilton agreement", reference.source_description
    assert_nil @deposit.reload.percentage

    mismatched = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        amount_shape: "fixed_amount", fixed_amount_minor_units: 1, currency: "USD",
        rule_shape: "fixed_date", rule_parameters: { "date" => "2026-12-01" },
        precision: "date_only", time_zone: "America/New_York",
        coverage_links: [], cost_links: [], contributor_definition_ids: []
      }
    ).call.record
    assert_equal 1, mismatched.fixed_amount_minor_units
    assert_equal 10_000, @deposit.reload.fixed_amount_minor_units

    CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: @definition.reload,
      definition_lock_version: @definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Changed rate", economic_role: "supplier_charge", calculation_kind: "unit_rate",
        amount_minor_units: 99_900, quantity_basis: "resource_nights", pass_through: false
      }
    ).call

    assert_equal DERIVATION, reference.reload.governing_wording
    assert_equal 10_000, @deposit.reload.fixed_amount_minor_units
    assert_equal 1, mismatched.reload.fixed_amount_minor_units

    replay = record_reference(kind: "deposit_derivation", governing_wording: DERIVATION)
    assert_equal :replayed, replay.status
    assert_equal reference.id, replay.record.id
    assert_equal 1, @version.supplier_agreement_references.where(arrangement_item: @item, kind: "deposit_derivation").count
  end

  test "agreement references keep exact wording and reject another agency, a viewer, and a later kind" do
    attrition = record_reference(kind: "attrition", governing_wording: ATTRITION).record
    assert_equal ATTRITION, attrition.governing_wording
    assert_nil attrition.original_wording
    assert_nil @version.supplier_agreement_references.find_by(arrangement_item: other_item.fetch(:item), kind: "attrition")

    refund = record_reference(
      kind: "deposit_refund", governing_wording: GOVERNING, original_wording: ORIGINAL,
      evidence_note: "Recorded from the agreement", idempotency_key: SecureRandom.uuid
    ).record
    assert_equal ORIGINAL, refund.original_wording
    assert_equal GOVERNING, refund.governing_wording
    assert_equal @admin.id, refund.recorded_by_id
    assert_not_includes SupplierAgreementReference.column_names, "refund_due_on"
    assert_not_includes SupplierAgreementReference.column_names, "payer"
    assert_not_includes SupplierAgreementReference.column_names, "recipient"

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordSupplierAgreementReference.new(
        agency: agencies(:cove), actor: agency_users(:cove_admin), arrangement_item: @item,
        kind: "deposit_refund", governing_wording: GOVERNING, original_wording: ORIGINAL,
        source_description: SOURCE, idempotency_key: SecureRandom.uuid
      ).call
    end
    viewer = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReference.new(
        agency: @agency, actor: agency_users(:harbor_viewer), arrangement_item: @item,
        kind: "deposit_refund", governing_wording: GOVERNING, original_wording: ORIGINAL,
        source_description: SOURCE, idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :unauthorized, viewer.code

    later_kind = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReference.new(
        agency: @agency, actor: @admin, arrangement_item: @item, kind: "cancellation",
        governing_wording: "No separate cancellation schedule.", source_description: SOURCE,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, later_kind.code

    missing_item = assert_raises(AgencyCommand::Error) do
      RecordSupplierAgreementReference.new(
        agency: @agency, actor: @admin, arrangement_item: nil, kind: "attrition",
        governing_wording: ATTRITION, source_description: SOURCE, idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, missing_item.code
  end

  test "successor copies agreement references and an omitted copy cannot activate" do
    derivation = record_reference(kind: "deposit_derivation", governing_wording: DERIVATION).record
    record_reference(kind: "attrition", governing_wording: ATTRITION)
    refund = record_reference(
      kind: "deposit_refund", governing_wording: GOVERNING, original_wording: ORIGINAL,
      idempotency_key: SecureRandom.uuid
    ).record
    prepare_activation!
    ActivateDeparture.new(
      agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload, version: @version.reload,
      arrangement_lock_version: @arrangement.lock_version, version_lock_version: @version.lock_version,
      cost_source_coverage_acknowledged: true, commitment_trigger_coverage_acknowledged: true,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.new(2026, 9, 28), channel: "email",
        reference_note: "Confirmed without a hotel number.",
        confirmed_without_identifier_reason: "No hotel number was issued."
      }
    ).call

    assert_raises(ActiveRecord::RecordNotFound) do
      SetSupplierCostCommissionTreatment.new(
        agency: @agency, actor: @admin, definition: @definition.reload,
        commission_treatment: "noncommissionable", lock_version: @definition.lock_version
      ).call
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      derivation.reload.update!(governing_wording: "Changed after confirmation.")
    end

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version, version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copied = successor.supplier_agreement_references.order(:kind).to_a
    assert_equal %w[attrition deposit_derivation deposit_refund], copied.map(&:kind)
    copied_refund = copied.find { |reference| reference.deposit_refund? }
    assert_equal refund.id, copied_refund.copied_from_id
    assert_equal GOVERNING, copied_refund.governing_wording
    assert_equal ORIGINAL, copied_refund.original_wording
    assert_equal refund.reload.recorded_at, copied_refund.recorded_at

    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @admin, arrangement_item: @item, kind: "deposit_refund",
      lock_version: copied_refund.lock_version, source_description: SOURCE,
      original_wording: ORIGINAL, governing_wording: "#{GOVERNING} Revised on the successor."
    ).call
    assert_equal GOVERNING, refund.reload.governing_wording
    assert_equal "#{GOVERNING} Revised on the successor.", copied_refund.reload.governing_wording
    assert_equal DERIVATION, derivation.reload.governing_wording

    copied_refund.destroy!
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: successor
    ).call
    assert_includes readiness.blockers.map(&:code), :copied_lineage_invalid
  end

  private

  DERIVATION = "November 4 Standard 5 x 17300. Total 415600. Shares 1000, 4500, and 4500."
  ATTRITION = "November 4 minimum 7. November 5 minimum 15. Lost room revenue at 100 percent. Rates 17300 and 22300. Quoted tax 1650 basis points."
  SOURCE = "Hilton agreement"

  def record_reference(kind:, governing_wording:, original_wording: nil, evidence_note: nil, idempotency_key: "term-#{kind}")
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @admin, arrangement_item: @item, kind: kind,
      governing_wording: governing_wording, original_wording: original_wording,
      source_description: SOURCE, evidence_note: evidence_note, idempotency_key: idempotency_key
    ).call
  end

  def other_item
    item = CreateArrangementItem.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Other stay", category: "lodging" }
    ).call.record
    occurrence = CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Other night", starts_on: "2027-11-05", ends_on: "2027-11-05" }
    ).call.record
    { item: item, occurrence: occurrence }
  end

  def prepare_activation!
    UpdateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, definition: @definition.reload, lock_version: @definition.lock_version,
      attributes: {
        mode: "zero_cost", currency: "USD", rounding_mode: "half_up",
        zero_cost_reason: "Included in the stay"
      }
    ).call
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: @definition.reload,
      lock_version: @definition.lock_version, readiness_provenance: "Term proof"
    ).call
  end
end
