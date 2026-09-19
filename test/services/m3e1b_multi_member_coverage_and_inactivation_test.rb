# frozen_string_literal: true

require "test_helper"

class M3e1bMultiMemberCoverageAndInactivationTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    ensure_supplier_sequence!
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Multi Coverage Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin, current_office: offices(:harbor_main),
      attributes: {
        name: "Multi Coverage Departure", starts_on: Date.new(2027, 7, 1),
        ends_on: Date.new(2027, 7, 5), time_zone: "America/New_York",
        operating_currency: "USD", responsible_office_id: offices(:harbor_main).id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Multi Coverage Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
    @opening_confirmation = create_confirmation!(
      evidence_kind: "supplier_confirmation",
      reference_note: "Opening confirmation"
    )
    @satisfaction_confirmation = create_confirmation!(
      evidence_kind: "supplier_confirmation",
      reference_note: "Shared satisfaction evidence"
    )
    @first = open_commitment!("First guarantee", 3)
    @second = open_commitment!("Second guarantee", 5)
  end

  test "one evidence coverage satisfies multiple open commitments" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal 2, coverage.members.count
    assert_equal "satisfied", @first.reload.disposition_outcome
    assert_equal "satisfied", @second.reload.disposition_outcome
    assert_equal coverage.id, @first.current_disposition.supplier_commitment_evidence_coverage_id
    assert_equal coverage.id, @second.current_disposition.supplier_commitment_evidence_coverage_id
  end

  test "exact-member disqualification reopens one commitment and retains the other" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record

    DisqualifySupplierCommitmentFromEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage:, commitment: @first,
      reason: "Wrong member included", idempotency_key: SecureRandom.uuid
    ).call

    assert @first.reload.open_state?
    assert_equal "satisfied", @second.reload.disposition_outcome
    assert_equal 2, SupplierCommitmentEvidenceCoverageMember.where(
      supplier_commitment_evidence_coverage_id: coverage.id
    ).count
    assert AuditEvent.exists?(action: "supplier_arrangement.evidence_member_disqualified")
  end

  test "whole coverage revocation reopens every current dependent" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record

    RevokeSupplierCommitmentEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage:,
      reason: "Evidence recorded against wrong set", idempotency_key: SecureRandom.uuid
    ).call

    assert @first.reload.open_state?
    assert @second.reload.open_state?
    assert coverage.reload.revoked?
    assert AuditEvent.exists?(action: "supplier_arrangement.evidence_coverage_revoked")
  end

  test "revocation after one disqualification only reopens remaining dependents" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record
    DisqualifySupplierCommitmentFromEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage:, commitment: @first,
      reason: "Remove first", idempotency_key: SecureRandom.uuid
    ).call

    RevokeSupplierCommitmentEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage: coverage.reload,
      reason: "Revoke remaining", idempotency_key: SecureRandom.uuid
    ).call

    assert @first.reload.open_state?
    assert @second.reload.open_state?
  end

  test "terminal dispositions stop blocking ordinary Supplier inactivation" do
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call
    abandon_arrangement!

    result = ChangeSupplierStatus.new(
      agency: @agency, actor: @admin, supplier: @supplier.reload,
      status: "inactive", lock_version: @supplier.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal "inactive", @supplier.reload.status
  end

  test "open commitments still block ordinary Supplier inactivation" do
    abandon_arrangement!

    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency, actor: @admin, supplier: @supplier.reload,
        status: "inactive", lock_version: @supplier.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code
    assert_match(/unresolved supplier commitments/i, error.message)
  end

  test "waived commitments do not block ordinary inactivation" do
    WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @first,
      reason: "Accepted exception", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call
    WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @second,
      reason: "Accepted exception", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call
    abandon_arrangement!

    result = ChangeSupplierStatus.new(
      agency: @agency, actor: @admin, supplier: @supplier.reload,
      status: "inactive", lock_version: @supplier.lock_version
    ).call
    assert_equal :updated, result.status
  end

  test "other agency cannot revoke foreign coverage" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record

    assert_raises(ActiveRecord::RecordNotFound) do
      RevokeSupplierCommitmentEvidenceCoverage.new(
        agency: agencies(:cove), actor: agency_users(:cove_admin), coverage:,
        reason: "Cross agency", idempotency_key: SecureRandom.uuid
      ).call
    end
  end

  test "direct sql cannot mutate revocation history" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation,
      commitment_ids: [ @first.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record
    revocation = RevokeSupplierCommitmentEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage:,
      reason: "Immutable", idempotency_key: SecureRandom.uuid
    ).call.record

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE supplier_commitment_evidence_coverage_revocations SET reason = 'rewritten' WHERE id = '#{revocation.id}'"
      )
    end
  end

  private

  def create_confirmation!(evidence_kind:, reference_note:)
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @supplier,
      evidence_kind: evidence_kind, evidence_on: Date.current,
      channel: "phone", reference_note: reference_note,
      actor: @staff, recorded_at: Time.current
    )
  end

  def open_commitment!(description, quantity)
    trigger = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        trigger_kind: "arrangement_confirmation",
        authority_shape: "fixed_quantity",
        description: description,
        committed_supplier_id: @supplier.id,
        fixed_quantity: quantity,
        quantity_basis: "resource_units"
      }
    ).call.record
    OpenSupplierCommitmentAlreadyLocked.new(
      trigger:, confirmation: @opening_confirmation, actor: @staff
    ).call
  end

  def abandon_arrangement!
    AbandonSupplierArrangement.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      reason: "Clear arrangement dependency for inactivation proof",
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version
    ).call
  end

  def ensure_supplier_sequence!
    @agency.reference_sequences.find_or_create_by!(
      namespace: ReferenceSequence::SUPPLIER_NAMESPACE
    ) { |sequence| sequence.next_value = 1 }
  end
end
