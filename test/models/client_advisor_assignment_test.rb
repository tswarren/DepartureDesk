require "test_helper"

class ClientAdvisorAssignmentTest < ActiveSupport::TestCase
  test "overlapping closed intervals are rejected" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    now = Time.current
    first = assignment_row(
      profile:,
      membership: agency_memberships(:one),
      from: Date.new(2026, 1, 1),
      until_date: Date.new(2026, 6, 1),
      now:
    )

    ClientAdvisorAssignment.insert_all!([ first ])

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.insert_all!([
          assignment_row(
            profile:,
            membership: agency_memberships(:staff_one),
            from: Date.new(2026, 3, 1),
            until_date: Date.new(2026, 9, 1),
            now:
          )
        ])
      end
    end
  end

  test "identity columns cannot change after create" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    assignment = ClientAdvisorAssignment.create!(
      agency: agencies(:one),
      client_profile: profile,
      advisor_membership: agency_memberships(:one),
      effective_from: Date.new(2026, 1, 1),
      effective_until: Date.new(2026, 2, 1),
      ended_at: Time.current,
      ended_by_membership: agency_memberships(:one),
      ending_reason: "Ended"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.connection.execute(
          "UPDATE client_advisor_assignments SET advisor_membership_id = '#{agency_memberships(:staff_one).id}' WHERE id = '#{assignment.id}'"
        )
      end
    end
  end

  test "current advisor pointer must agree with the open history row" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      profile:,
      membership: agency_memberships(:one)
    ).call

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.connection.execute(<<~SQL.squish)
          UPDATE client_profiles
          SET primary_advisor_membership_id = '#{agency_memberships(:staff_one).id}'
          WHERE id = '#{profile.id}'
        SQL
        enforce_advisor_agreement!
      end
    end
    assert_match(/current advisor must agree with open assignment history/, error.message)
    assert_equal agency_memberships(:one).id, profile.reload.primary_advisor_membership_id
  end

  test "an open assignment cannot exist without a matching profile pointer" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    now = Time.current

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.insert_all!([
          open_assignment_row(profile:, membership: agency_memberships(:one), from: Date.new(2026, 1, 1), now:)
        ])
        enforce_advisor_agreement!
      end
    end
    assert_match(/current advisor must agree with open assignment history/, error.message)
    assert_equal 0, ClientAdvisorAssignment.where(client_profile: profile).count
  end

  test "ending the open assignment while leaving the pointer set is rejected" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      profile:,
      membership: agency_memberships(:one)
    ).call
    assignment = profile.open_advisor_assignment
    today = DirectoryDate.today(agencies(:one))

    error = assert_raises(ActiveRecord::StatementInvalid) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.connection.execute(<<~SQL.squish)
          UPDATE client_advisor_assignments
          SET effective_until = DATE '#{today}',
              ended_at = CURRENT_TIMESTAMP,
              ended_by_membership_id = '#{agency_memberships(:one).id}',
              ending_reason = 'Ended without clearing pointer'
          WHERE id = '#{assignment.id}'
        SQL
        enforce_advisor_agreement!
      end
    end
    assert_match(/current advisor must agree with open assignment history/, error.message)
    assert_nil assignment.reload.effective_until
  end

  test "pointer and history may diverge mid-transaction when they agree at commit" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      profile:,
      membership: agency_memberships(:one)
    ).call
    assignment = profile.open_advisor_assignment
    now = Time.current
    today = DirectoryDate.today(agencies(:one))

    ClientAdvisorAssignment.transaction(requires_new: true) do
      ClientAdvisorAssignment.connection.execute(<<~SQL.squish)
        UPDATE client_advisor_assignments
        SET effective_until = DATE '#{today}',
            ended_at = CURRENT_TIMESTAMP,
            ended_by_membership_id = '#{agency_memberships(:one).id}',
            ending_reason = 'Reassigned in one transaction'
        WHERE id = '#{assignment.id}'
      SQL
      ClientAdvisorAssignment.insert_all!([
        open_assignment_row(profile:, membership: agency_memberships(:staff_one), from: today, now:)
      ])
      ClientProfile.connection.execute(<<~SQL.squish)
        UPDATE client_profiles
        SET primary_advisor_membership_id = '#{agency_memberships(:staff_one).id}',
            primary_advisor_membership_status = 'active'
        WHERE id = '#{profile.id}'
      SQL
      enforce_advisor_agreement!
    end

    assert_equal agency_memberships(:staff_one).id, profile.reload.primary_advisor_membership_id
    assert_equal agency_memberships(:staff_one).id, profile.open_advisor_assignment.advisor_membership_id
  end

  test "cross-agency advisor membership is rejected" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.insert_all!([
          assignment_row(
            profile:,
            membership: agency_memberships(:two),
            from: Date.new(2026, 1, 1),
            until_date: Date.new(2026, 2, 1),
            now:
          ).merge(agency_id: agencies(:one).id)
        ])
      end
    end
  end

  private

  def assignment_row(profile:, membership:, from:, until_date:, now:)
    {
      agency_id: profile.agency_id,
      client_profile_id: profile.id,
      advisor_membership_id: membership.id,
      effective_from: from,
      effective_until: until_date,
      ended_at: now,
      ended_by_membership_id: agency_memberships(:one).id,
      ending_reason: "Ended",
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def open_assignment_row(profile:, membership:, from:, now:)
    {
      agency_id: profile.agency_id,
      client_profile_id: profile.id,
      advisor_membership_id: membership.id,
      effective_from: from,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def enforce_advisor_agreement!
    ClientAdvisorAssignment.connection.execute(<<~SQL.squish)
      SET CONSTRAINTS
        client_profiles_advisor_agrees_with_open_assignment,
        client_advisor_assignments_agree_with_profile_pointer
      IMMEDIATE
    SQL
  end
end
