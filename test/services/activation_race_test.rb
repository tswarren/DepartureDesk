require "test_helper"

class ActivationRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @created_agency_ids = []
    @created_user_ids = []
  end

  teardown do
    purge_created_records
  end

  test "accept versus accept across two agencies leaves one usable membership" do
    user = create_user("race-accept-accept@example.com")
    agency_a = create_agency("Race Accept A")
    agency_b = create_agency("Race Accept B")
    membership_a = create_invited_membership(user:, agency: agency_a)
    membership_b = create_invited_membership(user:, agency: agency_b)
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      accepting_after_locate(membership_a.invitation_token, "WinnerPass123!", barrier).call
    end
    second = run_on_connection do
      accepting_after_locate(membership_b.invitation_token, "LoserPass123!", barrier).call
    end

    join_all!(first, second)
    assert_one_successful_activation(
      user:,
      memberships: [ membership_a, membership_b ],
      agencies: [ agency_a, agency_b ],
      passwords: [ "WinnerPass123!", "LoserPass123!" ],
      outcomes: [ first, second ]
    )
  end

  test "accept versus reactivate across two agencies leaves one usable membership" do
    user = create_user("race-accept-reactivate@example.com")
    agency_a = create_agency("Race Accept Reactivate A")
    agency_b = create_agency("Race Accept Reactivate B")
    admin_b = create_user("race-accept-reactivate-admin@example.com")
    create_active_admin(admin_b, agency_b)
    membership_a = create_invited_membership(user:, agency: agency_a)
    membership_b = create_membership(user:, agency: agency_b, status: "suspended", role: "staff")
    barrier = CyclicBarrier.new(2)

    accept = run_on_connection do
      accepting_after_locate(membership_a.invitation_token, "AcceptPass123!", barrier).call
    end
    reactivate = run_on_connection do
      reactivating_after_prepare(agency_b, membership_b, admin_b, barrier).call
    end

    join_all!(accept, reactivate)
    assert_one_successful_activation(
      user:,
      memberships: [ membership_a, membership_b ],
      agencies: [ agency_a, agency_b ],
      passwords: [ "AcceptPass123!", "OriginalPass123!" ],
      outcomes: [ accept, reactivate ]
    )
  end

  test "replacement versus acceptance keeps the obsolete token from activating" do
    user = create_user("race-replace-accept@example.com")
    agency = create_agency("Race Replace Accept")
    admin = create_user("race-replace-accept-admin@example.com")
    create_active_admin(admin, agency)
    membership = create_invited_membership(user:, agency:)
    original_digest = user.password_digest
    original_version = membership.invitation_version
    token = membership.invitation_token
    sequence = LocateThenMutateBarrier.new

    accept = run_on_connection do
      accepting_after_locate(token, "AcceptPass123!", sequence).call
    end
    replace = run_on_connection do
      sequence.run_after_locate do
        ReplaceInvitation.new(agency:, membership:, actor: admin).call
      end
    end

    join_all!(accept, replace)
    assert_kind_of MembershipCommand::Error, accept[:error]
    assert_equal :invalid_token, accept[:error].code
    assert_equal AcceptInvitation::GENERIC_FAILURE, accept[:error].message
    assert_nil accept[:result]
    assert replace[:result]
    assert_not_predicate membership.reload, :active?
    assert_operator membership.invitation_version, :>, original_version
    assert_equal original_digest, user.reload.password_digest
    assert_nil user.usable_agency_membership
    assert_equal 0, success_activation_audits(agency).count
    assert_equal [ "team.invitation_replaced" ], agency.audit_events.order(:created_at).pluck(:action)
  end

  test "revocation versus acceptance keeps the obsolete token from activating" do
    user = create_user("race-revoke-accept@example.com")
    agency = create_agency("Race Revoke Accept")
    admin = create_user("race-revoke-accept-admin@example.com")
    create_active_admin(admin, agency)
    membership = create_invited_membership(user:, agency:)
    original_digest = user.password_digest
    token = membership.invitation_token
    sequence = LocateThenMutateBarrier.new

    accept = run_on_connection do
      accepting_after_locate(token, "AcceptPass123!", sequence).call
    end
    revoke = run_on_connection do
      sequence.run_after_locate do
        RevokeInvitation.new(agency:, membership:, actor: admin).call
      end
    end

    join_all!(accept, revoke)
    assert_kind_of MembershipCommand::Error, accept[:error]
    assert_equal :invalid_token, accept[:error].code
    assert_equal AcceptInvitation::GENERIC_FAILURE, accept[:error].message
    assert_predicate membership.reload, :revoked?
    assert_equal original_digest, user.reload.password_digest
    assert_nil user.usable_agency_membership
    assert_equal 0, success_activation_audits(agency).count
  end

  test "two submissions of the same invitation token activate once" do
    user = create_user("race-same-token@example.com")
    agency = create_agency("Race Same Token")
    membership = create_invited_membership(user:, agency:)
    token = membership.invitation_token
    barrier = CyclicBarrier.new(2)

    first = run_on_connection do
      accepting_after_locate(token, "FirstPass123!", barrier).call
    end
    second = run_on_connection do
      accepting_after_locate(token, "SecondPass123!", barrier).call
    end

    join_all!(first, second)
    assert_one_successful_activation(
      user:,
      memberships: [ membership ],
      agencies: [ agency ],
      passwords: [ "FirstPass123!", "SecondPass123!" ],
      outcomes: [ first, second ]
    )
    assert_equal 1, [ first, second ].count { |outcome| outcome[:result] }
    assert_equal 1, [ first, second ].count { |outcome| outcome[:error] }
    assert_equal AcceptInvitation::GENERIC_FAILURE, [ first, second ].filter_map { |outcome| outcome[:error]&.message }.first
  end

  private

  def create_agency(name)
    agency = Agency.create!(
      name: name,
      default_timezone: "UTC",
      default_currency: "USD",
      country_code: "US"
    )
    @created_agency_ids << agency.id
    agency
  end

  def create_user(email)
    user = User.create!(
      email_address: email,
      first_name: "Race",
      last_name: "Tester",
      password: "OriginalPass123!",
      password_confirmation: "OriginalPass123!"
    )
    @created_user_ids << user.id
    user
  end

  def create_membership(user:, agency:, status:, role:)
    AgencyMembership.create!(
      user:,
      agency:,
      status:,
      role:,
      invitation_sent_at: Time.current
    )
  end

  def create_invited_membership(user:, agency:, role: "staff")
    create_membership(user:, agency:, status: "invited", role:)
  end

  def create_active_admin(user, agency)
    create_membership(user:, agency:, status: "active", role: "administrator")
  end

  def accepting_after_locate(token, password, barrier)
    Class.new(AcceptInvitation) do
      define_method(:after_locate) { |_| barrier.respond_to?(:after_locate) ? barrier.after_locate : barrier.wait }
    end.new(token:, password:, password_confirmation: password)
  end

  def reactivating_after_prepare(agency, membership, actor, barrier)
    Class.new(ReactivateMembership) do
      define_method(:before_activation) { barrier.wait }
    end.new(agency:, membership:, actor:)
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
        flunk "timed out waiting for a concurrent activation"
      end
    end
  end

  def assert_one_successful_activation(user:, memberships:, agencies:, passwords:, outcomes:)
    memberships.each(&:reload)
    user.reload

    active = memberships.select(&:active?)
    assert_equal 1, active.size
    assert_equal 1, user.agency_memberships.active.count
    assert_equal active.first.id, user.usable_agency_membership.id
    assert_equal active.first.agency_id, user.usable_agency_membership.agency_id

    matching = passwords.select { |password| User.authenticate_by(email_address: user.email_address, password:) }
    assert_equal 1, matching.size

    success_actions = %w[team.invitation_accepted team.membership_reactivated]
    successes = AuditEvent.where(agency_id: agencies.map(&:id), action: success_actions)
    assert_equal 1, successes.count
    assert_equal active.first.agency_id, successes.first.agency_id

    losing = memberships - active
    losing.each do |membership|
      assert_not_equal "active", membership.status
    end

    errors = outcomes.filter_map { |outcome| outcome[:error] }
    assert_equal 1, errors.size
    assert_kind_of MembershipCommand::Error, errors.first
    assert_not_kind_of ActiveRecord::RecordNotUnique, errors.first
    if errors.first.code == :invalid_token
      assert_equal AcceptInvitation::GENERIC_FAILURE, errors.first.message
    else
      assert_equal :conflict, errors.first.code
    end
  end

  def success_activation_audits(agency)
    agency.audit_events.where(action: %w[team.invitation_accepted team.membership_reactivated])
  end

  def purge_created_records
    agency_ids = @created_agency_ids
    user_ids = @created_user_ids
    return if agency_ids.empty? && user_ids.empty?

    membership_ids = AgencyMembership.where(agency_id: agency_ids).pluck(:id)
    Session.where(user_id: user_ids).delete_all
    DeliveryIntent.where(agency_id: agency_ids).delete_all
    DeliveryIntent.where(subject_type: "AgencyMembership", subject_id: membership_ids).delete_all

    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    AuditEvent.where(agency_id: agency_ids).delete_all
    connection.execute("SET session_replication_role = DEFAULT")

    AgencyMembership.where(agency_id: agency_ids).delete_all
    User.where(id: user_ids).delete_all
    Agency.where(id: agency_ids).delete_all
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
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

  class LocateThenMutateBarrier
    def initialize
      @mutex = Mutex.new
      @located = false
      @released = false
      @located_cv = ConditionVariable.new
      @released_cv = ConditionVariable.new
    end

    def after_locate
      @mutex.synchronize do
        @located = true
        @located_cv.broadcast
        @released_cv.wait(@mutex) until @released
      end
    end

    def run_after_locate
      @mutex.synchronize do
        @located_cv.wait(@mutex) until @located
      end
      yield
      @mutex.synchronize do
        @released = true
        @released_cv.broadcast
      end
    end
  end
end
