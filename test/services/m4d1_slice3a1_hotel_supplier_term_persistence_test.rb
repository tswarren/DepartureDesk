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

  test "deposit basis shares and entries stay fixed when the current rate changes" do
    basis = record_basis.record
    assert_equal 10_000, basis.basis_amount_minor_units
    entry = basis.supplier_deposit_basis_entries.sole
    assert_equal 1 * 10_000, entry.extended_amount_minor_units
    share = basis.supplier_deposit_basis_shares.sole
    assert_equal 10_000, share.share_basis_points
    assert_nil @deposit.reload.percentage
    assert_equal 10_000 * 10_000, basis.basis_amount_minor_units * share.share_basis_points
    assert_equal @deposit.fixed_amount_minor_units * 10_000, basis.basis_amount_minor_units * share.share_basis_points

    CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: @definition.reload,
      definition_lock_version: @definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Changed rate", economic_role: "supplier_charge", calculation_kind: "unit_rate",
        amount_minor_units: 99_900, quantity_basis: "resource_nights", pass_through: false
      }
    ).call

    assert_equal 10_000, basis.reload.basis_amount_minor_units
    assert_equal 10_000, basis.supplier_deposit_basis_entries.sole.agreed_unit_rate_minor_units
    assert_equal 10_000, @deposit.reload.fixed_amount_minor_units

    replay = record_basis
    assert_equal :replayed, replay.status
    assert_equal basis.id, replay.record.id
    assert_equal 1, @version.supplier_deposit_bases.where(arrangement_item: @item).count
  end

  test "attrition and refund clarification reject another item and keep exact wording" do
    policy = RecordHotelAttritionPolicy.new(
      agency: @agency, actor: @admin, arrangement_item: @item, idempotency_key: SecureRandom.uuid,
      quoted_tax_rate_basis_points: 1_650,
      nights: [ { service_occurrence_id: @occurrence.id, minimum_utilized_room_nights: 7 } ],
      zero_utilization_rates: [ { supplier_resource_id: @resource.id, amount_minor_units: 17_300 } ]
    ).call.record
    assert_equal "lost_room_revenue", policy.consequence
    assert_equal 10_000, policy.consequence_basis_points
    assert_equal 7, policy.hotel_attrition_nights.sole.minimum_utilized_room_nights
    assert_equal 17_300, policy.hotel_attrition_zero_utilization_rates.sole.amount_minor_units

    other = other_item
    assert_raises(ActiveRecord::RecordNotFound) do
      RecordHotelAttritionPolicy.new(
        agency: @agency, actor: @admin, arrangement_item: @item, idempotency_key: SecureRandom.uuid,
        quoted_tax_rate_basis_points: 1_650,
        nights: [ { service_occurrence_id: other.fetch(:occurrence).id, minimum_utilized_room_nights: 1 } ],
        zero_utilization_rates: [ { supplier_resource_id: @resource.id, amount_minor_units: 1 } ]
      ).call
    end
    assert_nil @version.hotel_attrition_policies.find_by(arrangement_item: other.fetch(:item))

    clarification = RecordSupplierDepositRefundClarification.new(
      agency: @agency, actor: @admin, arrangement_item: @item, idempotency_key: SecureRandom.uuid,
      original_wording: ORIGINAL, governing_wording: GOVERNING, refund_due_on: Date.new(2027, 11, 20),
      evidence_note: "Recorded from the agreement"
    ).call.record
    assert_equal ORIGINAL, clarification.original_wording
    assert_equal GOVERNING, clarification.governing_wording
    assert_equal "agency", clarification.payer
    assert_equal "agency", clarification.recipient
    assert_equal Date.new(2027, 11, 20), clarification.refund_due_on
    assert_equal @admin.id, clarification.recorded_by_id

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordSupplierDepositRefundClarification.new(
        agency: agencies(:cove), actor: agency_users(:cove_admin), arrangement_item: @item,
        idempotency_key: SecureRandom.uuid, original_wording: ORIGINAL, governing_wording: GOVERNING,
        refund_due_on: Date.new(2027, 11, 20)
      ).call
    end
    viewer = assert_raises(AgencyCommand::Error) do
      RecordSupplierDepositRefundClarification.new(
        agency: @agency, actor: agency_users(:harbor_viewer), arrangement_item: @item,
        idempotency_key: SecureRandom.uuid, original_wording: ORIGINAL, governing_wording: GOVERNING,
        refund_due_on: Date.new(2027, 11, 20)
      ).call
    end
    assert_equal :unauthorized, viewer.code
  end

  test "successor copies the historical basis and an omitted copy cannot activate" do
    basis = record_basis.record
    RecordHotelAttritionPolicy.new(
      agency: @agency, actor: @admin, arrangement_item: @item, idempotency_key: SecureRandom.uuid,
      quoted_tax_rate_basis_points: 1_650,
      nights: [ { service_occurrence_id: @occurrence.id, minimum_utilized_room_nights: 7 } ],
      zero_utilization_rates: [ { supplier_resource_id: @resource.id, amount_minor_units: 17_300 } ]
    ).call
    clarification = RecordSupplierDepositRefundClarification.new(
      agency: @agency, actor: @admin, arrangement_item: @item, idempotency_key: SecureRandom.uuid,
      original_wording: ORIGINAL, governing_wording: GOVERNING, refund_due_on: Date.new(2027, 11, 20)
    ).call.record
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
      basis.reload.update!(basis_amount_minor_units: 1)
    end

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version, version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copied_basis = successor.supplier_deposit_bases.sole
    assert_equal basis.id, copied_basis.copied_from_id
    assert_equal 10_000, copied_basis.basis_amount_minor_units
    assert_equal basis.supplier_deposit_basis_entries.sole.id, copied_basis.supplier_deposit_basis_entries.sole.copied_from_id
    copied_policy = successor.hotel_attrition_policies.sole
    assert_equal @version.hotel_attrition_policies.sole.id, copied_policy.copied_from_id
    copied_clarification = successor.supplier_deposit_refund_clarifications.sole
    assert_equal clarification.id, copied_clarification.copied_from_id
    assert_equal GOVERNING, copied_clarification.governing_wording
    assert_equal clarification.reload.recorded_at, copied_clarification.recorded_at

    RecordSupplierDepositRefundClarification.new(
      agency: @agency, actor: @admin, arrangement_item: @item,
      lock_version: copied_clarification.lock_version,
      original_wording: ORIGINAL, governing_wording: "#{GOVERNING} Revised on the successor.",
      refund_due_on: Date.new(2027, 11, 20)
    ).call
    assert_equal GOVERNING, clarification.reload.governing_wording
    assert_equal 10_000, basis.reload.basis_amount_minor_units
    assert_equal 10_000, copied_basis.reload.basis_amount_minor_units

    copied_basis.supplier_deposit_basis_entries.sole.destroy!
    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: successor
    ).call
    assert_includes readiness.blockers.map(&:code), :copied_lineage_invalid
  end

  private

  def record_basis
    CreateSupplierDepositBasis.new(
      agency: @agency, actor: @admin, arrangement_item: @item, currency: "USD",
      basis_amount_minor_units: 10_000, idempotency_key: "term-basis",
      entries: [ {
        service_occurrence_id: @occurrence.id, supplier_resource_id: @resource.id,
        agreed_quantity: 1, agreed_unit_rate_minor_units: 10_000, extended_amount_minor_units: 10_000
      } ],
      shares: [ { supplier_deposit_requirement_definition_id: @deposit.id, share_basis_points: 10_000 } ]
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
