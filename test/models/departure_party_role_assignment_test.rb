require "test_helper"

class DeparturePartyRoleAssignmentTest < ActiveSupport::TestCase
  test "database rejects a first current assignment that is not primary" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(ActiveRecord::StatementInvalid) do
      DeparturePartyRoleAssignment.transaction(requires_new: true) do
        DeparturePartyRoleAssignment.insert_all!([
          party_role_row(departure:, party: parties(:unlinked), role: "organizer", primary: false)
        ])
        enforce_party_role_primary!
      end
    end

    assert_match(/exactly one primary/, error.message)
    assert_equal 0, departure.party_role_assignments.count
  end

  test "database accepts a first current assignment that is primary" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    DeparturePartyRoleAssignment.transaction(requires_new: true) do
      DeparturePartyRoleAssignment.insert_all!([
        party_role_row(departure:, party: parties(:unlinked), role: "organizer", primary: true)
      ])
      enforce_party_role_primary!
    end

    assignment = departure.party_role_assignments.current.sole
    assert assignment.is_primary?
  end

  test "database rejects overlapping intervals for the same party and role" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call

    assert_raises(ActiveRecord::StatementInvalid) do
      DeparturePartyRoleAssignment.transaction(requires_new: true) do
        DeparturePartyRoleAssignment.insert_all!([
          party_role_row(departure:, party: parties(:unlinked), role: "organizer", primary: false)
        ])
      end
    end
  end

  private

  def party_role_row(departure:, party:, role:, primary:)
    now = Time.current
    {
      agency_id: departure.agency_id,
      departure_id: departure.id,
      party_id: party.id,
      party_kind: party.party_kind,
      role:,
      party_display_name_snapshot: party.display_name,
      is_primary: primary,
      effective_from: Date.new(2027, 7, 1),
      assigned_at: now,
      assigned_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def enforce_party_role_primary!
    DeparturePartyRoleAssignment.connection.execute(<<~SQL.squish)
      SET CONSTRAINTS dpra_current_role_has_one_primary IMMEDIATE
    SQL
  end
end
