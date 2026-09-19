# frozen_string_literal: true

require "test_helper"

class M3e1aCommitmentLifecycleTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    ensure_supplier_sequence!
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Lifecycle Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin, current_office: offices(:harbor_main),
      attributes: {
        name: "Lifecycle Departure", starts_on: Date.new(2027, 5, 1),
        ends_on: Date.new(2027, 5, 5), time_zone: "America/New_York",
        operating_currency: "USD", responsible_office_id: offices(:harbor_main).id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Lifecycle Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
    @trigger = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, version: @version,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        trigger_kind: "arrangement_confirmation",
        authority_shape: "fixed_quantity",
        description: "Ten guaranteed rooms",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 10,
        quantity_basis: "resource_units"
      }
    ).call.record
    @opening_confirmation = create_confirmation!(
      evidence_kind: "supplier_confirmation",
      reference_note: "Supplier confirmed the guarantee"
    )
    @satisfaction_confirmation = create_confirmation!(
      evidence_kind: "supplier_confirmation",
      reference_note: "Supplier confirmed rooms delivered"
    )
    @release_confirmation = create_confirmation!(
      evidence_kind: "supplier_release",
      reference_note: "Supplier released the guarantee"
    )
    @commitment = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: @trigger, confirmation: @opening_confirmation, actor: @staff
    ).call
  end

  test "opening migrates to confirmation_trigger kind" do
    assert_equal "confirmation_trigger", @commitment.opening_kind
    assert @commitment.open_state?
  end

  test "staff satisfies one commitment with compatible confirmation evidence" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal "satisfied", coverage.purpose
    assert_equal 1, coverage.members.count
    @commitment.reload
    assert_not @commitment.open_state?
    assert_equal "satisfied", @commitment.disposition_outcome
    assert AuditEvent.exists?(
      action: "supplier_arrangement.commitments_disposed",
      subject_type: "SupplierArrangement", subject_id: @arrangement.id
    )
  end

  test "staff releases with supplier_release evidence" do
    coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @release_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "released", idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal "released", coverage.purpose
    assert_equal "released", @commitment.reload.disposition_outcome
  end

  test "rejects opening confirmation as disposition evidence" do
    error = assert_raises(AgencyCommand::Error) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: @opening_confirmation, commitment_ids: [ @commitment.id ],
        outcome: "satisfied", idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "rejects ordinary booking confirmation for release" do
    error = assert_raises(AgencyCommand::Error) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
        outcome: "released", idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "rejects confirmation from another supplier" do
    other_supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "Other Lifecycle Supplier" }, categories: [ "lodging" ]
    ).call.record
    foreign_confirmation = create_confirmation!(
      supplier: other_supplier,
      evidence_kind: "supplier_confirmation",
      reference_note: "Wrong supplier evidence"
    )

    error = assert_raises(AgencyCommand::Error) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: foreign_confirmation, commitment_ids: [ @commitment.id ],
        outcome: "satisfied", idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "same evidence dispose key replays without duplicating dispositions" do
    key = SecureRandom.uuid
    first = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @release_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "released", idempotency_key: key
    ).call
    assert_equal :created, first.status

    assert_no_changes -> { SupplierCommitmentDisposition.count } do
      second = DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: @release_confirmation, commitment_ids: [ @commitment.id ],
        outcome: "released", idempotency_key: key
      ).call
      assert_equal :replayed, second.status
      assert_equal first.record.id, second.record.id
    end
  end

  test "dispose key with different occurred_at conflicts" do
    key = SecureRandom.uuid
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "satisfied", idempotency_key: key,
      occurred_at: Time.zone.parse("2027-04-01 12:00:00")
    ).call

    other = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: create_second_trigger!, confirmation: @opening_confirmation, actor: @staff
    ).call

    error = assert_raises(AgencyCommand::Error) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: @satisfaction_confirmation, commitment_ids: [ other.id ],
        outcome: "satisfied", idempotency_key: key,
        occurred_at: Time.zone.parse("2027-04-02 12:00:00")
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "conflicting dispose replay raises" do
    key = SecureRandom.uuid
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "satisfied", idempotency_key: key
    ).call

    other = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: create_second_trigger!, confirmation: @opening_confirmation, actor: @staff
    ).call
    error = assert_raises(AgencyCommand::Error) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        confirmation: @release_confirmation, commitment_ids: [ other.id ],
        outcome: "released", idempotency_key: key
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "administrator waives with override permission" do
    disposition = WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @commitment,
      reason: "Group cancelled before deposit terms applied.",
      accepted_risk_acknowledged: true, idempotency_key: SecureRandom.uuid
    ).call.record

    assert_equal "waived", disposition.outcome
    assert_equal "waived", @commitment.reload.disposition_outcome
  end

  test "staff cannot waive" do
    error = assert_raises(AgencyCommand::Error) do
      WaiveSupplierCommitment.new(
        agency: @agency, actor: @staff, commitment: @commitment,
        reason: "Should fail", accepted_risk_acknowledged: true,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "reopen restores open state against current disposition" do
    disposition = WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @commitment,
      reason: "Temporary waiver", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call.record

    ReopenSupplierCommitment.new(
      agency: @agency, actor: @staff, commitment: @commitment,
      disposition:, reason: "Waiver recorded in error",
      idempotency_key: SecureRandom.uuid
    ).call

    assert @commitment.reload.open_state?
    assert AuditEvent.exists?(action: "supplier_arrangement.commitment_reopened")
  end

  test "reopen rejects already-open commitment" do
    disposition = WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @commitment,
      reason: "Temporary waiver", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call.record
    ReopenSupplierCommitment.new(
      agency: @agency, actor: @staff, commitment: @commitment,
      disposition:, reason: "Corrected", idempotency_key: SecureRandom.uuid
    ).call

    error = assert_raises(AgencyCommand::Error) do
      ReopenSupplierCommitment.new(
        agency: @agency, actor: @staff, commitment: @commitment.reload,
        disposition:, reason: "Again", idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "database rejects a second current disposition" do
    WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @commitment,
      reason: "First current waiver", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_dispositions (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_id, outcome, reason, accepted_risk_acknowledged, actor_id,
          occurred_at, recorded_at, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{@commitment.id}', 'waived', 'Second current waiver', TRUE, '#{@admin.id}',
          NOW(), NOW(), NOW(), NOW()
        )
      SQL
    end
  end

  test "database rejects disposition without coverage membership" do
    coverage = SupplierCommitmentEvidenceCoverage.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_confirmation: @satisfaction_confirmation,
      purpose: "satisfied", actor: @staff, recorded_at: Time.current
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_dispositions (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_id, outcome, supplier_commitment_evidence_coverage_id,
          accepted_risk_acknowledged, actor_id, occurred_at, recorded_at, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{@commitment.id}', 'satisfied', '#{coverage.id}',
          FALSE, '#{@staff.id}', NOW(), NOW(), NOW(), NOW()
        )
      SQL
    end
  end

  test "database rejects coverage purpose mismatch" do
    coverage = SupplierCommitmentEvidenceCoverage.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_confirmation: @release_confirmation,
      purpose: "released", actor: @staff, recorded_at: Time.current
    )
    SupplierCommitmentEvidenceCoverageMember.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_commitment_evidence_coverage: coverage,
      supplier_commitment: @commitment
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_dispositions (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_id, outcome, supplier_commitment_evidence_coverage_id,
          accepted_risk_acknowledged, actor_id, occurred_at, recorded_at, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{@commitment.id}', 'satisfied', '#{coverage.id}',
          FALSE, '#{@staff.id}', NOW(), NOW(), NOW(), NOW()
        )
      SQL
    end
  end

  test "database seals coverage membership after disposition" do
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call
    coverage = SupplierCommitmentEvidenceCoverage.order(:created_at).last
    other = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: create_second_trigger!, confirmation: @opening_confirmation, actor: @staff
    ).call

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        INSERT INTO supplier_commitment_evidence_coverage_members (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_evidence_coverage_id, supplier_commitment_id, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{coverage.id}', '#{other.id}', NOW(), NOW()
        )
      SQL
    end
  end

  test "direct sql cannot mutate disposition history" do
    disposition = WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: @commitment,
      reason: "Immutable history", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call.record

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE supplier_commitment_dispositions SET reason = 'rewritten' WHERE id = '#{disposition.id}'"
      )
    end
  end

  test "direct sql rejects mixed opening kind" do
    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "INSERT INTO supplier_commitments (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_arrangement_version_id,
          supplier_commitment_trigger_definition_id, supplier_confirmation_id, committed_supplier_id,
          commitment_type, description, calculation_snapshot, actor_id, opened_at, opening_kind,
          quantity, quantity_basis, created_at, updated_at
        ) VALUES (
          uuidv7(), '#{@agency.id}', '#{@departure.id}', '#{@arrangement.id}', '#{@version.id}',
          '#{@trigger.id}', '#{@opening_confirmation.id}', '#{@supplier.id}',
          'quantity', 'bad', 'snapshot', '#{@staff.id}', NOW(), 'deposit_requirement',
          1, 'resource_units', NOW(), NOW()
        )"
      )
    end
  end

  test "commitments index uses a bounded query count for disposition state" do
    second = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: create_second_trigger!, confirmation: @opening_confirmation, actor: @staff
    ).call
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call
    WaiveSupplierCommitment.new(
      agency: @agency, actor: @admin, commitment: second,
      reason: "Accepted exception", accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call

    commitments = @arrangement.supplier_commitments.with_current_disposition_state
      .includes(:committed_supplier, :supplier_confirmation)
      .order(opened_at: :desc, id: :desc)
      .to_a

    queries = count_queries do
      open_count = commitments.count(&:open_state?)
      waived_count = commitments.count { |commitment| commitment.disposition_outcome == "waived" }
      terminal_count = commitments.reject(&:open_state?).count { |commitment| commitment.disposition_outcome != "waived" }
      assert_equal 0, open_count
      assert_equal 1, waived_count
      assert_equal 1, terminal_count
    end

    assert_operator queries, :<=, 0
  end

  test "other agency cannot load foreign arrangement for dispose" do
    other = agencies(:cove)
    assert_raises(ActiveRecord::RecordNotFound) do
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: other, actor: agency_users(:cove_admin), arrangement: @arrangement,
        confirmation: @satisfaction_confirmation, commitment_ids: [ @commitment.id ],
        outcome: "satisfied", idempotency_key: SecureRandom.uuid
      ).call
    end
  end

  private

  def create_confirmation!(evidence_kind:, reference_note:, supplier: @supplier)
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: supplier,
      evidence_kind: evidence_kind, evidence_on: Date.current,
      channel: "phone", reference_note: reference_note,
      actor: @staff, recorded_at: Time.current
    )
  end

  def create_second_trigger!
    CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @staff, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        trigger_kind: "arrangement_confirmation",
        authority_shape: "fixed_quantity",
        description: "Second guarantee",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 2,
        quantity_basis: "resource_units"
      }
    ).call.record
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, **) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def ensure_supplier_sequence!
    @agency.reference_sequences.find_or_create_by!(
      namespace: ReferenceSequence::SUPPLIER_NAMESPACE
    ) { |sequence| sequence.next_value = 1 }
  end
end
