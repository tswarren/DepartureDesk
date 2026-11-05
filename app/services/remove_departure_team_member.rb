# Removes a user from a Departure's team. Removing the default task owner
# leaves the Departure without one (OPS-12).
class RemoveDepartureTeamMember < DepartureTeamCommand
  private

  def change!(departure)
    user = member_user!
    membership = membership!(departure, user)
    was_owner = membership.default_task_owner
    membership.destroy!
    audit_team!(departure, "departure.team_member_removed", user, "was_default_task_owner" => was_owner)
    Result.new(status: :updated, record: departure)
  end
end
