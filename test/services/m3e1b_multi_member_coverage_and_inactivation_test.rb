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
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record

    assert_equal 2, coverage.members.count
    assert_equal "satisfied", @first.reload.disposition_outcome
    assert_equal "satisfied", @second.reload.disposition_outcome
    assert_equal coverage.id, @first.current_disposition.supplier_commitment_evidence_coverage_id
    assert_equal coverage.id, @second.current_disposition.supplier_commitment_evidence_coverage_id
  end

  test "exact-member disqualification reopens one commitment and retains the other" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    disqualify!(coverage:, commitment: @first, reason: "Wrong member included")

    assert @first.reload.open_state?
    assert_equal "satisfied", @second.reload.disposition_outcome
    assert_equal 2, SupplierCommitmentEvidenceCoverageMember.where(
      supplier_commitment_evidence_coverage_id: coverage.id
    ).count
    assert AuditEvent.exists?(action: "supplier_arrangement.evidence_member_disqualified")
  end

  test "whole coverage revocation reopens every current dependent" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    revoke!(coverage:, commitment_ids: [ @first.id, @second.id ], reason: "Evidence recorded against wrong set")

    assert @first.reload.open_state?
    assert @second.reload.open_state?
    assert coverage.reload.revoked?
    assert AuditEvent.exists?(action: "supplier_arrangement.evidence_coverage_revoked")
  end

  test "revocation after one disqualification only reopens remaining dependents" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    disqualify!(coverage:, commitment: @first, reason: "Remove first")
    revoke!(coverage: coverage.reload, commitment_ids: [ @second.id ], reason: "Revoke remaining")

    assert @first.reload.open_state?
    assert @second.reload.open_state?
  end

  test "disqualification same-key replay returns replayed" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    disposition = @first.current_disposition
    key = SecureRandom.uuid
    first = disqualify!(
      coverage:, commitment: @first, disposition_id: disposition.id,
      reason: "Wrong member", idempotency_key: key
    )
    assert_equal :created, first.status

    second = disqualify!(
      coverage:, commitment: @first, disposition_id: disposition.id,
      reason: "Wrong member", idempotency_key: key
    )
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
  end

  test "disqualification same-key different payload conflicts" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    disposition = @first.current_disposition
    key = SecureRandom.uuid
    disqualify!(
      coverage:, commitment: @first, disposition_id: disposition.id,
      reason: "First reason", idempotency_key: key
    )

    error = assert_raises(AgencyCommand::Error) do
      disqualify!(
        coverage:, commitment: @first, disposition_id: disposition.id,
        reason: "Different reason", idempotency_key: key
      )
    end
    assert_equal :conflict, error.code
  end

  test "revocation same-key replay returns replayed after dependents reopen" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    key = SecureRandom.uuid
    ids = [ @first.id, @second.id ]
    first = revoke!(coverage:, commitment_ids: ids, reason: "Revoke set", idempotency_key: key)
    assert_equal :created, first.status

    second = revoke!(coverage:, commitment_ids: ids, reason: "Revoke set", idempotency_key: key)
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
  end

  test "revocation same-key different reviewed set conflicts" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    key = SecureRandom.uuid
    revoke!(coverage:, commitment_ids: [ @first.id, @second.id ], reason: "Revoke", idempotency_key: key)

    error = assert_raises(AgencyCommand::Error) do
      revoke!(coverage:, commitment_ids: [ @first.id ], reason: "Revoke", idempotency_key: key)
    end
    assert_equal :conflict, error.code
  end

  test "database rejects disqualification paired with unrelated reopening" do
    coverage = dispose!(commitment_ids: [ @first.id, @second.id ]).record
    first_disposition = @first.current_disposition
    second_disposition = @second.current_disposition
    ReopenSupplierCommitment.new(
      agency: @agency, actor: @staff, commitment: @second, disposition: second_disposition,
      reason: "Ordinary reopen of other member", idempotency_key: SecureRandom.uuid
    ).call
    foreign_reopening = @second.supplier_commitment_reopenings.sole

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_evidence_member_disqualifications (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_evidence_coverage_id, supplier_commitment_id,
          supplier_commitment_disposition_id, supplier_commitment_reopening_id,
          reason, actor_id, occurred_at, recorded_at, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{coverage.id}', '#{@first.id}',
          '#{first_disposition.id}', '#{foreign_reopening.id}',
          'Cross-linked reopening', '#{@staff.id}', NOW(), NOW(), NOW(), NOW()
        )
      SQL
    end
  end

  test "database rejects disqualification with disposition from another coverage" do
    first_coverage = dispose!(commitment_ids: [ @first.id ]).record
    reopen_for_second_coverage!
    second_coverage = dispose!(
      confirmation: create_confirmation!(
        evidence_kind: "supplier_confirmation",
        reference_note: "Second satisfaction evidence"
      ),
      commitment_ids: [ @first.id ]
    ).record
    disposition = @first.current_disposition
    assert_equal second_coverage.id, disposition.supplier_commitment_evidence_coverage_id
    ReopenSupplierCommitment.new(
      agency: @agency, actor: @staff, commitment: @first, disposition:,
      reason: "Ordinary reopen", idempotency_key: SecureRandom.uuid
    ).call
    reopening = @first.supplier_commitment_reopenings.order(:recorded_at, :id).last

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_evidence_member_disqualifications (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_evidence_coverage_id, supplier_commitment_id,
          supplier_commitment_disposition_id, supplier_commitment_reopening_id,
          reason, actor_id, occurred_at, recorded_at, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{first_coverage.id}', '#{@first.id}',
          '#{disposition.id}', '#{reopening.id}',
          'Wrong coverage disposition', '#{@staff.id}', NOW(), NOW(), NOW(), NOW()
        )
      SQL
    end
  end

  test "terminal dispositions stop blocking ordinary Supplier inactivation" do
    dispose!(commitment_ids: [ @first.id, @second.id ])
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
    coverage = dispose!(commitment_ids: [ @first.id ]).record

    assert_raises(ActiveRecord::RecordNotFound) do
      revoke!(
        agency: agencies(:cove), actor: agency_users(:cove_admin), coverage:,
        commitment_ids: [ @first.id ], reason: "Cross agency"
      )
    end
  end

  test "direct sql cannot mutate revocation history" do
    coverage = dispose!(commitment_ids: [ @first.id ]).record
    revocation = revoke!(coverage:, commitment_ids: [ @first.id ], reason: "Immutable").record

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE supplier_commitment_evidence_coverage_revocations SET reason = 'rewritten' WHERE id = '#{revocation.id}'"
      )
    end
  end

  private

  def dispose!(commitment_ids:, confirmation: @satisfaction_confirmation, idempotency_key: SecureRandom.uuid)
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation:, commitment_ids:, outcome: "satisfied", idempotency_key:
    ).call
  end

  def disqualify!(coverage:, commitment:, reason:, disposition_id: nil, idempotency_key: SecureRandom.uuid)
    DisqualifySupplierCommitmentFromEvidenceCoverage.new(
      agency: @agency, actor: @staff, coverage:, commitment:,
      disposition_id: disposition_id || commitment.current_disposition.id,
      reason:, idempotency_key:
    ).call
  end

  def revoke!(coverage:, commitment_ids:, reason:, agency: @agency, actor: @staff,
    idempotency_key: SecureRandom.uuid)
    RevokeSupplierCommitmentEvidenceCoverage.new(
      agency:, actor:, coverage:, commitment_ids:, reason:, idempotency_key:
    ).call
  end

  def reopen_for_second_coverage!
    disposition = @first.current_disposition
    ReopenSupplierCommitment.new(
      agency: @agency, actor: @staff, commitment: @first, disposition:,
      reason: "Prepare second coverage", idempotency_key: SecureRandom.uuid
    ).call
  end

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
