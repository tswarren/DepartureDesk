# frozen_string_literal: true

require "test_helper"

class M3e1bEvidenceCoverageConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3E1b race #{suffix}", workspace_code: "a#{suffix}",
      country_code: "US", default_currency: "USD", default_timezone: "UTC",
      office_name: "Race Office", office_code: "RACE", office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race", administrator_last_name: "Planner",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3e1b-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @actor, kind: "organization",
      names: { display_name: "Race Coverage Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @actor, current_office: @agency.offices.sole,
      attributes: {
        name: "Race Coverage Departure", starts_on: Date.new(2027, 8, 1),
        ends_on: Date.new(2027, 8, 5), time_zone: "UTC",
        operating_currency: "USD", responsible_office_id: @agency.offices.sole.id,
        responsible_agency_user_id: @actor.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Race Coverage Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
    opening = create_confirmation!("Opening")
    satisfaction = create_confirmation!("Satisfaction")
    @first = open_commitment!("First", 2, opening)
    @second = open_commitment!("Second", 4, opening)
    @coverage = DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      confirmation: satisfaction, commitment_ids: [ @first.id, @second.id ],
      outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call.record
  end

  teardown do
    agency_id = @agency&.id
    next unless agency_id

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      %w[
        supplier_commitment_evidence_member_disqualifications
        supplier_commitment_evidence_coverage_revocations
        supplier_commitment_reopenings supplier_commitment_dispositions
        supplier_commitment_evidence_coverage_members supplier_commitment_evidence_coverages
        supplier_confirmation_commitment_links supplier_commitments
        supplier_commitment_trigger_definitions supplier_confirmations
        agency_command_idempotency_keys audit_events
        supplier_arrangement_versions supplier_arrangements
      ].each do |table|
        ActiveRecord::Base.connection.execute(
          "DELETE FROM #{table} WHERE agency_id = #{ActiveRecord::Base.connection.quote(agency_id)}"
        )
      end
    end
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "concurrent revoke and disqualify of overlapping members produce one coherent outcome" do
    reviewed_ids = [ @first.id, @second.id ]
    first_disposition_id = @first.current_disposition.id

    outcomes = race do |index|
      if index.zero?
        RevokeSupplierCommitmentEvidenceCoverage.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          coverage: SupplierCommitmentEvidenceCoverage.find(@coverage.id),
          commitment_ids: reviewed_ids,
          reason: "Race revoke",
          idempotency_key: "race-revoke"
        ).call
      else
        DisqualifySupplierCommitmentFromEvidenceCoverage.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          coverage: SupplierCommitmentEvidenceCoverage.find(@coverage.id),
          commitment: SupplierCommitment.find(@first.id),
          disposition_id: first_disposition_id,
          reason: "Race disqualify",
          idempotency_key: "race-disqualify"
        ).call
      end
    end

    successes = outcomes.select { |outcome| outcome.is_a?(AgencyCommand::Result) && outcome.status == :created }
    failures = outcomes.select { |outcome| outcome.is_a?(AgencyCommand::Error) }
    assert_equal 1, successes.size
    assert_equal 1, failures.size
    assert_includes %i[invalid_state conflict], failures.first.code
    assert @first.reload.open_state?
  end

  private

  def create_confirmation!(note)
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @supplier,
      evidence_kind: "supplier_confirmation", evidence_on: Date.current,
      channel: "portal", reference_note: note,
      actor: @actor, recorded_at: Time.current
    )
  end

  def open_commitment!(description, quantity, confirmation)
    trigger = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
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
      trigger:, confirmation:, actor: @actor
    ).call
  end

  def race
    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    outcomes = threads.map(&:value)
    outcomes.each do |outcome|
      next if outcome.is_a?(AgencyCommand::Result)
      next if outcome.is_a?(AgencyCommand::Error) &&
        %i[invalid invalid_state conflict].include?(outcome.code)

      raise outcome
    end
    outcomes
  end
end
