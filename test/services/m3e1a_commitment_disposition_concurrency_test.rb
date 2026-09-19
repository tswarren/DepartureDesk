# frozen_string_literal: true

require "test_helper"

class M3e1aCommitmentDispositionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3E1a race #{suffix}", workspace_code: "a#{suffix}",
      country_code: "US", default_currency: "USD", default_timezone: "UTC",
      office_name: "Race Office", office_code: "RACE", office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race", administrator_last_name: "Planner",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3e1a-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @actor, kind: "organization",
      names: { display_name: "Race Commitment Supplier" }, categories: [ "lodging" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @actor, current_office: @agency.offices.sole,
      attributes: {
        name: "Race Commitment Departure", starts_on: Date.new(2027, 6, 1),
        ends_on: Date.new(2027, 6, 5), time_zone: "UTC",
        operating_currency: "USD", responsible_office_id: @agency.offices.sole.id,
        responsible_agency_user_id: @actor.id
      }
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Race Arrangement", contracting_supplier_id: @supplier.id }
    ).call.record
    @version = @arrangement.versions.first
    @trigger = CreateSupplierCommitmentTriggerDefinition.new(
      agency: @agency, actor: @actor, version: @version,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        trigger_kind: "arrangement_confirmation",
        authority_shape: "fixed_quantity",
        description: "Race guarantee",
        committed_supplier_id: @supplier.id,
        fixed_quantity: 4,
        quantity_basis: "resource_units"
      }
    ).call.record
    @opening_confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @supplier,
      evidence_kind: "supplier_confirmation", evidence_on: Date.current,
      channel: "portal", reference_note: "Opening confirmation",
      actor: @actor, recorded_at: Time.current
    )
    @release_confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, confirming_supplier: @supplier,
      evidence_kind: "supplier_release", evidence_on: Date.current,
      channel: "portal", reference_note: "Release confirmation",
      actor: @actor, recorded_at: Time.current
    )
    @commitment = OpenSupplierCommitmentAlreadyLocked.new(
      trigger: @trigger, confirmation: @opening_confirmation, actor: @actor
    ).call
  end

  teardown do
    agency_id = @agency&.id
    next unless agency_id

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      %w[
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

  test "two concurrent releases of one commitment produce one disposition without deadlock" do
    outcomes = race do |index|
      DisposeSupplierCommitmentsWithEvidence.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        arrangement: SupplierArrangement.find(@arrangement.id),
        confirmation: SupplierConfirmation.find(@release_confirmation.id),
        commitment_ids: [ @commitment.id ],
        outcome: "released",
        idempotency_key: "race-release-#{index}"
      ).call
    end

    successes = outcomes.select { |outcome| outcome.is_a?(AgencyCommand::Result) }
    failures = outcomes.select { |outcome| outcome.is_a?(AgencyCommand::Error) }
    assert_equal 1, successes.size
    assert_equal 1, failures.size
    assert_equal :invalid_state, failures.first.code
    assert_equal 1, SupplierCommitmentDisposition.where(supplier_commitment_id: @commitment.id).count
    assert_equal "released", @commitment.reload.disposition_outcome
  end

  test "disposition versus departure-first locker does not deadlock" do
    outcomes = race do |index|
      if index.zero?
        DisposeSupplierCommitmentsWithEvidence.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          confirmation: SupplierConfirmation.find(@release_confirmation.id),
          commitment_ids: [ @commitment.id ],
          outcome: "released",
          idempotency_key: "race-lock-order-dispose"
        ).call
      else
        ActiveRecord::Base.transaction do
          agency = Agency.lock.find(@agency.id)
          agency.suppliers.lock.find(@supplier.id)
          agency.departures.lock.find(@departure.id)
          sleep 0.05
          agency.supplier_arrangements.lock.find(@arrangement.id)
        end
        :locked
      end
    end

    assert(outcomes.any? { |outcome| outcome.is_a?(AgencyCommand::Result) && outcome.status == :created })
    assert_includes outcomes, :locked
    assert_equal "released", @commitment.reload.disposition_outcome
  end

  private

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
      next if outcome == :locked
      next if outcome.is_a?(AgencyCommand::Result)
      next if outcome.is_a?(AgencyCommand::Error) &&
        %i[invalid invalid_state conflict].include?(outcome.code)

      raise outcome
    end
    outcomes
  end
end
