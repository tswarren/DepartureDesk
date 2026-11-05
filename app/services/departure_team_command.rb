# Shared steps for the Departure team commands (ACC-09, OPS-12). Each needs
# Departure management, locks the agency then the Departure, refuses a
# Departed Departure (DEP-43) and audits against the Departure.
class DepartureTeamCommand < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, agency_user_id:)
    @agency = agency
    @actor = actor
    @departure = departure
    @agency_user_id = agency_user_id
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      raise Error.new("A departed departure's team cannot change.", code: :invalid_state) if departure.departed?

      change!(departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def member_user!
    user = resolve_agency_user!(@agency_user_id)
    raise Error.new("Choose a team member.", code: :invalid) if user.nil?

    user
  end

  def membership!(departure, user)
    departure.team_members.find_by(agency_user_id: user.id) ||
      raise(Error.new("That user is not on this departure's team.", code: :not_found))
  end

  def audit_team!(departure, action, user, extra = {})
    audit!(
      agency: @agency, action:, subject: departure, actor: @actor,
      details: { "departure_id" => departure.id, "agency_user_id" => user&.id }.merge(extra)
    )
  end
end
