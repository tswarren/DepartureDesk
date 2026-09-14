require "test_helper"

class LastAdministratorRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @password = "race-password1"
    @agency = ProvisionAgency.new(
      name: "Race Agency #{SecureRandom.hex(3)}",
      workspace_code: "race#{SecureRandom.hex(3)}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "one@example.com",
      administrator_first_name: "One",
      administrator_last_name: "Admin",
      administrator_password: @password,
      actor_identifier: "test:race"
    ).call.record
    @first = @agency.agency_users.sole
    @second = @agency.agency_users.create!(
      email_address: "two@example.com",
      first_name: "Two",
      last_name: "Admin",
      password: @password,
      password_confirmation: @password,
      access_role: "administrator",
      status: "active",
      credential_version: 1
    )
  end

  teardown do
    return unless @agency

    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    user_ids = AgencyUser.where(agency_id: @agency.id).pluck(:id)
    AuditEvent.where(agency_id: @agency.id).delete_all
    Session.where(agency_user_id: user_ids).delete_all
    AgencyUser.where(id: user_ids).delete_all
    Office.where(agency_id: @agency.id).delete_all
    Agency.where(id: @agency.id).delete_all
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent demotions cannot leave the agency without an active administrator" do
    barrier = CyclicBarrier.new(2)
    first = run_on_connection do
      barrier.wait
      ChangeAgencyUserAccess.new(agency_user: AgencyUser.find(@first.id), actor: AgencyUser.find(@second.id), access_role: "staff").call
    end
    second = run_on_connection do
      barrier.wait
      ChangeAgencyUserAccess.new(agency_user: AgencyUser.find(@second.id), actor: AgencyUser.find(@first.id), access_role: "staff").call
    end
    join_all!(first, second)

    assert_equal 1, @agency.agency_users.where(status: "active", access_role: "administrator").count
    errors = [ first, second ].filter_map { |outcome| outcome[:error] }
    successes = [ first, second ].count { |outcome| outcome[:result] }
    assert_equal 1, successes
    assert_equal 1, errors.size
    assert_includes [ :last_administrator, :unauthorized ], errors.first.code
  end

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
        flunk "timed out waiting for concurrent administrator mutation"
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
