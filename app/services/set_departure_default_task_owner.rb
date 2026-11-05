# Names one team member as the Departure's default task owner, or clears it
# when agency_user_id is blank (OPS-12). A routing convenience; it grants
# nothing.
class SetDepartureDefaultTaskOwner < DepartureTeamCommand
  private

  def change!(departure)
    user = @agency_user_id.present? ? member_user! : nil
    membership = user && membership!(departure, user)
    current = departure.team_members.find_by(default_task_owner: true)
    return Result.new(status: :noop, record: departure) if current&.id == membership&.id

    current&.update!(default_task_owner: false)
    membership&.update!(default_task_owner: true)
    audit_team!(departure, "departure.default_task_owner_changed", user, "previous_agency_user_id" => current&.agency_user_id)
    Result.new(status: :updated, record: departure)
  end
end
