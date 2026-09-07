require "test_helper"

class AdvisorSuspendRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @party = create_person!(agencies(:one), given_name: "Race", family_name: "Advisor#{SecureRandom.hex(4)}").party
    @profile = assign_client_role!(@party, actor: users(:one))
    @advisor = invite_and_accept_advisor
    @other_advisor = agency_memberships(:one)
  end

  teardown do
    return unless @party

    profile_ids = ClientProfile.where(party_id: @party.id).pluck(:id)
    assignment_ids = ClientAdvisorAssignment.where(client_profile_id: profile_ids).pluck(:id)
    membership_id = @advisor&.id
    person_id = @advisor&.person_party_id
    user_id = @advisor&.user_id
    advisor_party_id = @advisor&.person_party&.party_id
    office_assignment_ids = OfficeAssignment.where(agency_membership_id: membership_id).pluck(:id) if membership_id
    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(subject_type: "ClientAdvisorAssignment", subject_id: assignment_ids).delete_all
    AuditEvent.where(subject_type: "ClientProfile", subject_id: profile_ids).delete_all
    AuditEvent.where(subject_type: "AgencyMembership", subject_id: membership_id).delete_all if membership_id
    AuditEvent.where(subject_type: "OfficeAssignment", subject_id: office_assignment_ids).delete_all if office_assignment_ids
    AuditEvent.where(subject_type: "Party", subject_id: advisor_party_id).delete_all if advisor_party_id
    AuditEvent.where(subject_type: "Person", subject_id: person_id).delete_all if person_id
    ClientAdvisorAssignment.where(client_profile_id: profile_ids).delete_all
    ClientProfile.where(party_id: @party.id).delete_all
    connection.execute("SET session_replication_role = DEFAULT")
    Person.where(party_id: @party.id).delete_all
    @party.delete
    if @advisor
      Session.where(user_id:).delete_all if user_id
      DeliveryIntent.where(subject_type: "AgencyMembership", subject_id: membership_id).delete_all
      OfficeAssignment.where(agency_membership_id: membership_id).delete_all
      AgencyMembership.where(id: membership_id).delete_all
      Person.where(party_id: advisor_party_id).delete_all if advisor_party_id
      Party.where(id: advisor_party_id).delete_all if advisor_party_id
      User.where(id: user_id).delete_all if user_id
    end
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent advisor assignment and membership suspension leave a consistent advisor" do
    barrier = CyclicBarrier.new(2)

    assigned = run_on_connection do
      barrier.wait
      AssignClientAdvisor.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        profile: @profile,
        membership: @advisor
      ).call
    end
    suspended = run_on_connection do
      barrier.wait
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: @advisor
      ).call
    end

    join_all!(assigned, suspended)

    membership = @advisor.reload
    profile = @profile.reload
    errors = [ assigned, suspended ].filter_map { |outcome| outcome[:error] }
    successes = [ assigned, suspended ].count { |outcome| outcome[:result] }

    assert_equal 1, successes
    assert_equal 1, errors.size
    unless errors.first.is_a?(MembershipCommand::Error)
      assert_match(/deadlock/i, errors.first.message)
    end

    if membership.suspended?
      assert_nil profile.primary_advisor_membership_id
      assert_nil profile.open_advisor_assignment
    else
      assert membership.active?
      assert_equal membership.id, profile.primary_advisor_membership_id
      assert_equal "active", profile.primary_advisor_membership_status
      assert_equal membership.id, profile.open_advisor_assignment.advisor_membership_id
    end
    assert_equal 0, overlapping_assignment_count(profile)
  end

  test "concurrent advisor assignment produces one current advisor and no overlapping history" do
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      barrier.wait
      AssignClientAdvisor.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        profile: @profile,
        membership: @advisor
      ).call
    end
    second = run_on_connection do
      barrier.wait
      AssignClientAdvisor.new(
        agency: agencies(:one),
        actor: users(:one),
        party: @party,
        profile: @profile,
        membership: @other_advisor
      ).call
    end

    join_all!(first, second)

    profile = @profile.reload
    errors = [ first, second ].filter_map { |outcome| outcome[:error] }
    successes = [ first, second ].count { |outcome| outcome[:result] }

    assert_operator successes, :>=, 1
    assert_includes [ @advisor.id, @other_advisor.id ], profile.primary_advisor_membership_id
    assert_equal profile.primary_advisor_membership_id, profile.open_advisor_assignment&.advisor_membership_id
    assert_equal 1, ClientAdvisorAssignment.open.where(client_profile: profile).count
    assert_equal 0, overlapping_assignment_count(profile)
    errors.each do |error|
      next if error.is_a?(MembershipCommand::Error)

      assert_match(/deadlock/i, error.message)
    end
  end

  private

  def invite_and_accept_advisor
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "race.advisor.#{SecureRandom.hex(8)}@example.com",
      role: "staff",
      first_name: "Race",
      last_name: "Advisor",
      **invite_offices
    ).call.membership
    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end

  def overlapping_assignment_count(profile)
    ClientAdvisorAssignment.connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM client_advisor_assignments a
      JOIN client_advisor_assignments b
        ON a.client_profile_id = b.client_profile_id
       AND a.id < b.id
       AND daterange(a.effective_from, a.effective_until, '[)') &&
           daterange(b.effective_from, b.effective_until, '[)')
      WHERE a.client_profile_id = '#{profile.id}'
    SQL
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
        flunk "timed out waiting for concurrent advisor mutation"
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
