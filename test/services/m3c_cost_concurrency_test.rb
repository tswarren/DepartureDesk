require "test_helper"

class M3CCostConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3C Source Race #{suffix}",
      workspace_code: "c#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "America/New_York",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "America/New_York",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race",
      administrator_last_name: "Admin",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3c-#{suffix}"
    ).call.record
    @admin = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "M3C source race #{suffix}",
      starts_on: Date.new(2027, 9, 1),
      ends_on: Date.new(2027, 9, 2),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_office: @office,
      responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}",
      display_name: "M3C Race Supplier #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "M3C race arrangement #{suffix}"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
  end

  teardown do
    next unless @agency&.persisted?

    agency_id = @agency.id
    AgencyCommandIdempotencyKey.where(agency_id: agency_id).delete_all
    SupplierCostComponentBase.where(agency_id: agency_id).delete_all
    SupplierCostComponent.where(agency_id: agency_id).delete_all
    SupplierCostDefinition.where(agency_id: agency_id).delete_all
    SupplierCostSource.where(agency_id: agency_id).delete_all
    SupplierArrangementVersion.where(agency_id: agency_id).delete_all
    SupplierArrangement.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "parallel same-key source create replays one payload and changed payload conflicts" do
    key = "m3c-concurrent-source"
    original_lock = @version.lock_version
    outcomes = race(2) do
      CreateSupplierCostSource.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@admin.id),
        arrangement: SupplierArrangement.find(@arrangement.id),
        version_lock_version: original_lock,
        idempotency_key: key,
        attributes: {
          charging_supplier_id: @supplier.id,
          label: "Concurrent arrangement fee"
        }
      ).call
    end

    assert_equal %i[created replayed], outcomes.map(&:status).sort
    assert_equal 1, outcomes.map { |result| result.record.id }.uniq.size
    assert_equal 1, SupplierCostSource.where(supplier_arrangement_id: @arrangement.id).count
    key_record = AgencyCommandIdempotencyKey.find_by!(
      agency: @agency,
      command_name: "CreateSupplierCostSource",
      idempotency_key: key
    )
    assert_match(/\Asha256:[0-9a-f]{64}\z/, key_record.payload_digest)
    assert_equal 1, AuditEvent.where(
      subject_type: "SupplierArrangement",
      subject_id: @arrangement.id,
      action: "supplier_arrangement.cost_source_created"
    ).count

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierCostSource.new(
        agency: @agency,
        actor: @admin,
        arrangement: @arrangement,
        version_lock_version: original_lock,
        idempotency_key: key,
        attributes: {
          charging_supplier_id: @supplier.id,
          label: "Different arrangement fee"
        }
      ).call
    end
    assert_equal :conflict, error.code
    assert_equal "Concurrent arrangement fee", outcomes.first.record.reload.label
  end

  private

  def race(count)
    ready = Queue.new
    release = Queue.new
    threads = count.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield
        end
      rescue StandardError => error
        error
      end
    end
    count.times { ready.pop }
    count.times { release << true }
    outcomes = threads.map(&:value)
    outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }
    outcomes
  end
end
