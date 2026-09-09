require "test_helper"

class DepartureOfficeRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @office = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Race Desk",
      code: "R#{SecureRandom.hex(4).upcase[0, 9]}",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: @office,
      make_default: true
    ).call
  end

  teardown do
    return unless @office

    connection = ActiveRecord::Base.connection
    departure_ids = Departure.where(office_id: @office.id).pluck(:id)
    departure_ids += Departure.where(office_id: @keep_office&.id).pluck(:id) if @keep_office
    departure_ids.uniq!
    connection.execute("SET session_replication_role = replica")
    SupplierConfirmation.where(departure_id: departure_ids).delete_all
    SupplierCapacityEvent.where(departure_id: departure_ids).delete_all
    SupplierCapacityPosition.where(departure_id: departure_ids).delete_all
    SupplierServiceOccurrence.where(departure_id: departure_ids).delete_all
    SupplierReservationResource.where(departure_id: departure_ids).delete_all
    SupplierResource.where(departure_id: departure_ids).delete_all
    SupplierReservation.where(departure_id: departure_ids).delete_all
    SupplierArrangement.where(departure_id: departure_ids).delete_all
    AuditEvent.where(subject_type: "Departure", subject_id: departure_ids).delete_all
    AuditEvent.where(subject_type: "Office", subject_id: @office.id).delete_all
    AuditEvent.where(subject_type: "Office", subject_id: @keep_office&.id).delete_all if @keep_office
    AuditEvent.where(subject_type: "SupplierArrangement").delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    DepartureTeamAssignment.where(departure_id: departure_ids).delete_all
    Departure.where(id: departure_ids).delete_all
    DepartureReferenceCounter.where(agency_id: agencies(:one).id).delete_all if departure_ids.any?
    connection.execute("SET session_replication_role = replica")
    OfficeAssignment.where(office_id: [ @office.id, @keep_office&.id ].compact).delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    @office.delete
    @keep_office&.delete
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent create and office deactivation leave a consistent office and departure" do
    @keep_office = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Keep Open",
      code: "K#{SecureRandom.hex(4).upcase[0, 9]}",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    barrier = CyclicBarrier.new(2)

    created = run_on_connection do
      barrier.wait
      CreateDeparture.new(
        agency: agencies(:one),
        actor: users(:one),
        office: @office,
        name: "Race Departure",
        start_date: Date.new(2027, 7, 12),
        end_date: Date.new(2027, 7, 19),
        creation_idempotency_key: SecureRandom.uuid
      ).call
    end
    deactivated = run_on_connection do
      barrier.wait
      ChangeOfficeStatus.new(
        agency: agencies(:one),
        actor: users(:one),
        office: @office,
        to: "inactive",
        reason: "Concurrent close"
      ).call
    end

    join_all!(created, deactivated)

    office = @office.reload
    departure = Departure.find_by(office_id: @office.id)
    errors = [ created, deactivated ].filter_map { |outcome| outcome[:error] }
    successes = [ created, deactivated ].count { |outcome| outcome[:result] }

    assert_equal 1, successes
    assert_equal 1, errors.size
    assert_kind_of MembershipCommand::Error, errors.first

    if office.inactive?
      assert_nil departure
    else
      assert office.active?
      assert departure.draft?
      assert_equal "active", departure.owning_office_status
    end
  end

  test "concurrent first supplier arrangement and office transfer cannot mix ownership" do
    @keep_office = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Transfer Keep",
      code: "K#{SecureRandom.hex(4).upcase[0, 9]}",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: @keep_office,
      make_default: false
    ).call
    supplier_party = create_organization!(
      agencies(:one),
      legal_name: "Race Supplier #{SecureRandom.hex(4)}"
    ).party
    assign_supplier_role!(supplier_party, actor: users(:one), office: @office)
    departure = create_departure!(
      agencies(:one),
      actor: users(:one),
      office: @office,
      name: "Transfer Race Departure"
    )
    barrier = CyclicBarrier.new(2)

    created = run_on_connection do
      barrier.wait
      CreateSupplierArrangement.new(
        agency: agencies(:one),
        actor: users(:one),
        departure: Departure.find(departure.id),
        supplier_party: Party.find(supplier_party.id),
        name: "Race Arrangement"
      ).call
    end
    transferred = run_on_connection do
      barrier.wait
      TransferDepartureOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        departure: Departure.find(departure.id),
        office: Office.find(@keep_office.id)
      ).call
    end

    join_all!(created, transferred)

    errors = [ created, transferred ].filter_map { |outcome| outcome[:error] }
    successes = [ created, transferred ].count { |outcome| outcome[:result] }
    departure.reload
    arrangement = SupplierArrangement.find_by(departure_id: departure.id)

    assert_equal 1, successes
    assert_equal 1, errors.size
    assert_kind_of MembershipCommand::Error, errors.first
    if arrangement
      assert_equal :office_transfer_frozen, errors.first.code
      assert_equal departure.office_id, arrangement.office_id
      assert_equal @office.id, departure.office_id
    else
      assert_equal @keep_office.id, departure.office_id
    end
  ensure
    if defined?(supplier_party) && supplier_party
      connection = ActiveRecord::Base.connection
      connection.execute("SET session_replication_role = replica")
      SupplierProfile.where(party_id: supplier_party.id).delete_all
      Organization.where(party_id: supplier_party.id).delete_all
      Party.where(id: supplier_party.id).delete_all
      connection.execute("SET session_replication_role = DEFAULT")
    end
  end

  test "concurrent duplicate capacity hold applies once" do
    supplier_party = create_organization!(
      agencies(:one),
      legal_name: "Capacity Race Supplier #{SecureRandom.hex(4)}"
    ).party
    assign_supplier_role!(supplier_party, actor: users(:one), office: @office)
    departure = create_departure!(
      agencies(:one),
      actor: users(:one),
      office: @office,
      name: "Capacity Race Departure"
    )
    arrangement = CreateSupplierArrangement.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      supplier_party:,
      name: "Capacity Race Arrangement"
    ).call.supplier_arrangement
    resource = CreateSupplierResource.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      name: "Race Rooms",
      resource_kind: "room_type",
      capacity_unit: "room"
    ).call.supplier_resource
    occurrence = CreateSupplierServiceOccurrence.new(
      agency: agencies(:one),
      actor: users(:one),
      resource:,
      occurrence_kind: "night_slice",
      service_date: Date.new(2027, 7, 12)
    ).call.supplier_service_occurrence
    key = SecureRandom.uuid
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      barrier.wait
      HoldSupplierCapacity.new(
        agency: agencies(:one),
        actor: users(:one),
        resource: SupplierResource.find(resource.id),
        service_occurrence: SupplierServiceOccurrence.find(occurrence.id),
        quantity: 4,
        reason: "Concurrent initial hold",
        idempotency_key: key
      ).call
    end
    second = run_on_connection do
      barrier.wait
      HoldSupplierCapacity.new(
        agency: agencies(:one),
        actor: users(:one),
        resource: SupplierResource.find(resource.id),
        service_occurrence: SupplierServiceOccurrence.find(occurrence.id),
        quantity: 4,
        reason: "Concurrent initial hold",
        idempotency_key: key
      ).call
    end

    join_all!(first, second)

    assert_nil first[:error]
    assert_nil second[:error]
    assert_equal 1, SupplierCapacityEvent.where(idempotency_key: key).count
    assert_equal 4, SupplierCapacityPosition.find_by!(resource_id: resource.id, service_occurrence_id: occurrence.id).agency_held
  ensure
    if defined?(supplier_party) && supplier_party
      connection = ActiveRecord::Base.connection
      connection.execute("SET session_replication_role = replica")
      SupplierProfile.where(party_id: supplier_party.id).delete_all
      Organization.where(party_id: supplier_party.id).delete_all
      Party.where(id: supplier_party.id).delete_all
      connection.execute("SET session_replication_role = DEFAULT")
    end
  end

  private

  def run_on_connection
    outcome = {}
    thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        outcome[:result] = yield
      rescue StandardError => error
        outcome[:error] = error
      end
    end
    outcome[:thread] = thread
    outcome
  end

  def join_all!(*outcomes)
    outcomes.each do |outcome|
      unless outcome[:thread].join(8)
        outcome[:thread].kill
        flunk "timed out waiting for concurrent departure and office mutation"
      end
    end
  end

  class CyclicBarrier
    def initialize(parties)
      @parties = parties
      @waiting = 0
      @generation = 0
      @mutex = Mutex.new
      @cond = ConditionVariable.new
    end

    def wait
      @mutex.synchronize do
        generation = @generation
        @waiting += 1
        if @waiting == @parties
          @waiting = 0
          @generation += 1
          @cond.broadcast
        else
          @cond.wait(@mutex) while generation == @generation
        end
      end
    end
  end
end
