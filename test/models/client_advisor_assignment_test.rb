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
      effective_from: Date.new(2026, 1, 1)
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientAdvisorAssignment.transaction(requires_new: true) do
        ClientAdvisorAssignment.connection.execute(
          "UPDATE client_advisor_assignments SET advisor_membership_id = '#{agency_memberships(:staff_one).id}' WHERE id = '#{assignment.id}'"
        )
      end
    end
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
end
