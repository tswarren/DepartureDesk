class UpdateDepartureResponsibility < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, office_id:, agency_user_id:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @office_id = office_id
    @agency_user_id = agency_user_id
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      ensure_current_lock_version!(departure)
      office = resolve_office!(@office_id)
      user = resolve_agency_user!(@agency_user_id)
      locked_office = lock_office!(office)
      locked_user = lock_agency_user!(user)
      ensure_assignment_allowed!(departure, locked_office, locked_user)
      return Result.new(status: :noop, record: departure) if same_pair?(departure, locked_office, locked_user)

      previous = {
        "responsible_office_id" => departure.responsible_office_id,
        "responsible_agency_user_id" => departure.responsible_agency_user_id
      }
      departure.update!(responsible_office: locked_office, responsible_agency_user: locked_user)
      audit!(
        agency: @agency,
        action: "departure.responsibility_changed",
        subject: departure,
        actor: @actor,
        details: previous.merge(
          "departure_id" => departure.id,
          "new_responsible_office_id" => departure.responsible_office_id,
          "new_responsible_agency_user_id" => departure.responsible_agency_user_id
        )
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_assignment_allowed!(departure, office, user)
    if departure.draft?
      ensure_active_target!(office, "That office is not active.") if office.present?
      ensure_active_target!(user, "That agency user is not active.") if user.present?
      return
    end

    if office.nil? || user.nil?
      raise Error.new("Active and departed departures require a responsible office and agency user.", code: :invalid_state)
    end

    ensure_active_target!(office, "That office is not active.")
    ensure_active_target!(user, "That agency user is not active.")
  end

  def same_pair?(departure, office, user)
    departure.responsible_office_id == office&.id && departure.responsible_agency_user_id == user&.id
  end
end
