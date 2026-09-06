require "test_helper"

class RelationshipCorrectionRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @origin = create_person!(agencies(:one), given_name: "Race", family_name: "Origin#{suffix}").party
    @related = create_person!(agencies(:one), given_name: "Race", family_name: "Related#{suffix}").party
    @relationship = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: @origin,
      related_party: @related,
      relationship_kind: "family",
      relationship_label: "other_family"
    ).call.relationship
  end

  teardown do
    return unless @origin

    relationship_ids = PartyRelationship.where(origin_party_id: [ @origin.id, @related.id ]).or(PartyRelationship.where(related_party_id: [ @origin.id, @related.id ])).pluck(:id)
    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(subject_type: "PartyRelationship", subject_id: relationship_ids).delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    PartyRelationship.where(id: relationship_ids).delete_all
    Person.where(party_id: [ @origin.id, @related.id ]).delete_all
    Party.where(id: [ @origin.id, @related.id ]).delete_all
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent corrections leave one winner" do
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      barrier.wait
      CorrectPartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship: @relationship,
        reason: "First correction",
        notes: "First"
      ).call
    end
    second = run_on_connection do
      barrier.wait
      CorrectPartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship: @relationship,
        reason: "Second correction",
        notes: "Second"
      ).call
    end

    join_all!(first, second)
    @relationship.reload
    assert @relationship.record_superseded?
    errors = [ first, second ].filter_map { |outcome| outcome[:error] }
    successes = [ first, second ].count { |outcome| outcome[:result] }
    assert_equal 1, successes
    assert_equal 1, errors.size
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
        flunk "timed out waiting for concurrent relationship correction"
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
