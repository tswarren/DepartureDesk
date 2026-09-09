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
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(subject_type: "Departure", subject_id: departure_ids).delete_all
    AuditEvent.where(subject_type: "Office", subject_id: @office.id).delete_all
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
