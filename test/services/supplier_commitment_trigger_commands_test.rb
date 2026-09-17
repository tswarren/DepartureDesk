require "test_helper"

class SupplierCommitmentTriggerCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    ensure_supplier_sequence!
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Trigger Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin, current_office: offices(:harbor_main),
      attributes: {
        name: "Trigger Command Departure", starts_on: Date.new(2027, 4, 1),
        ends_on: Date.new(2027, 4, 5), time_zone: "America/New_York",
        operating_currency: "USD", responsible_office_id: offices(:harbor_main).id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Trigger Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
  end

  test "staff creates updates and removes fixed quantity trigger on exact draft version" do
    result = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, version: @version,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: valid_attributes
    ).call
    trigger = result.record
    assert_equal @version.id, trigger.supplier_arrangement_version_id
    assert_equal "fixed_quantity", trigger.authority_shape
    assert AuditEvent.exists?(
      action: "supplier_arrangement.commitment_trigger_created",
      subject_type: "SupplierArrangement", subject_id: @arrangement.id
    )

    UpdateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, trigger:,
      lock_version: trigger.lock_version,
      attributes: valid_attributes.merge(description: "Updated guarantee")
    ).call
    assert_equal "Updated guarantee", trigger.reload.description

    RemoveSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, trigger:,
      version_lock_version: @version.reload.lock_version
    ).call
    assert_not SupplierCommitmentTriggerDefinition.exists?(trigger.id)
  end

  test "viewer cannot create" do
    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierCommitmentTriggerDefinition.new(
        agency: @agency, actor: agency_users(:harbor_viewer), version: @version,
        version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
        attributes: valid_attributes
      ).call
    end
    assert_equal :unauthorized, error.code

  end

  test "readiness fails closed for incomplete exact graph" do
    result = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version
    ).call
    assert_not result.ready?
    assert_includes result.blockers.map(&:code), :items_missing
  end

  test "already locked opening creates one immutable quantity commitment" do
    trigger = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, version: @version,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: valid_attributes
    ).call.record
    confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @supplier,
      evidence_kind: "supplier_confirmation", evidence_on: Date.current,
      channel: "phone", reference_note: "Supplier confirmed the guarantee",
      actor: @staff, recorded_at: Time.current
    )

    commitment = OpenSupplierCommitmentAlreadyLocked.new(
      trigger:, confirmation:, actor: @staff
    ).call
    assert_equal 10, commitment.quantity
    assert_equal @supplier.id, commitment.committed_supplier_id
    assert_no_changes -> { SupplierCommitment.count } do
      assert_equal commitment.id, OpenSupplierCommitmentAlreadyLocked.new(
        trigger:, confirmation:, actor: @staff
      ).call.id
    end
    assert_not commitment.update(description: "Rewritten")
  end

  private

  def valid_attributes
    {
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Ten guaranteed rooms",
      committed_supplier_id: @supplier.id,
      fixed_quantity: 10,
      quantity_basis: "resource_units"
    }
  end

  def ensure_supplier_sequence!
    @agency.reference_sequences.find_or_create_by!(
      namespace: ReferenceSequence::SUPPLIER_NAMESPACE
    ) { |sequence| sequence.next_value = 1 }
  end
end
