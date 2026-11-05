# Adds an Agency Admin or staff user to a Departure's team (ACC-09).
class AddDepartureTeamMember < DepartureTeamCommand
  private

  def change!(departure)
    user = lock_agency_user!(member_user!)
    ensure_active_target!(user, "That agency user is not active.")
    return Result.new(status: :noop, record: departure) if departure.team_members.exists?(agency_user_id: user.id)

    departure.team_members.create!(agency: @agency, agency_user: user)
    audit_team!(departure, "departure.team_member_added", user)
    Result.new(status: :updated, record: departure)
  end
end
