require "test_helper"

class RoleOfficeRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @party = create_person!(agencies(:one), given_name: "Race", family_name: "Role#{SecureRandom.hex(4)}").party
    @office = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Race Desk",
      code: "R#{SecureRandom.hex(4).upcase[0, 9]}",
      default_timezone: agencies(:one).default_timezone
    ).call.office
  end

  teardown do
    return unless @party

    profile_ids = ClientProfile.where(party_id: @party.id).pluck(:id)
    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(subject_type: "ClientProfile", subject_id: profile_ids).delete_all
    AuditEvent.where(subject_type: "Office", subject_id: @office&.id).delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    ClientProfile.where(party_id: @party.id).delete_all
    @office&.delete
    Person.where(party_id: @party.id).delete_all
    @party.delete
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent role activation and office deactivation leave a consistent office and profile" do
    barrier = CyclicBarrier.new(2)

    created = run_on_connection do
      barrier.wait
      CreateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        office: @office
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
    profile = ClientProfile.find_by(party_id: @party.id)
    errors = [ created, deactivated ].filter_map { |outcome| outcome[:error] }
    successes = [ created, deactivated ].count { |outcome| outcome[:result] }

    assert_equal 1, successes
    assert_equal 1, errors.size
    assert_kind_of MembershipCommand::Error, errors.first

    if office.inactive?
      assert_nil profile
    else
      assert office.active?
      assert profile.active?
      assert_equal "active", profile.responsible_office_status
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
        flunk "timed out waiting for concurrent role and office mutation"
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
