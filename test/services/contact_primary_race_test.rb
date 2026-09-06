require "test_helper"

class ContactPrimaryRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @party = create_person!(agencies(:one), given_name: "Race", family_name: "Contact#{SecureRandom.hex(4)}").party
    @first = create_email_contact!(@party, address: "race-one-#{SecureRandom.hex(4)}@example.com", actor: users(:one))
    @second = create_email_contact!(@party, address: "race-two-#{SecureRandom.hex(4)}@example.com", actor: users(:one))
  end

  teardown do
    return unless @party

    contact_ids = PartyContactPoint.where(party_id: @party.id).pluck(:id)
    assignment_ids = ContactPointPurposeAssignment.where(party_id: @party.id).pluck(:id)
    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(subject_type: "PartyContactPoint", subject_id: contact_ids).delete_all
    AuditEvent.where(subject_type: "ContactPointPurposeAssignment", subject_id: assignment_ids).delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    ContactPointPurposeAssignment.where(party_id: @party.id).delete_all
    PartyEmailAddress.where(contact_point_id: contact_ids).delete_all
    PartyContactPoint.where(party_id: @party.id).delete_all
    Person.where(party_id: @party.id).delete_all
    @party.delete
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent primary assignment leaves one valid priority-one row" do
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      barrier.wait
      AssignContactPointPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        contact_point: @first,
        purpose: "general",
        priority: 1
      ).call
    end
    second = run_on_connection do
      barrier.wait
      AssignContactPointPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        contact_point: @second,
        purpose: "general",
        priority: 1
      ).call
    end

    join_all!(first, second)

    today = DirectoryDate.today(agencies(:one))
    current = ContactPointPurposeAssignment.current_on(today).primary.where(
      party_id: @party.id,
      purpose: "general",
      contact_kind: "email"
    )
    assert_equal 1, current.count

    errors = [ first, second ].filter_map { |outcome| outcome[:error] }
    successes = [ first, second ].count { |outcome| outcome[:result] }
    assert_equal 1, successes
    assert_equal 1, errors.size
    assert_kind_of MembershipCommand::Error, errors.first
    assert_equal :conflict, errors.first.code
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
        flunk "timed out waiting for concurrent primary assignment"
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
