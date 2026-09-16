class MarkDepartureDeparted < AgencyCommand
  include DepartureCommandSupport

  SYSTEM_ACTOR_IDENTIFIER = "departures.mark_departed"

  def initialize(agency:, departure:, actor_kind:, actor: nil, actor_identifier: nil, lock_version: nil)
    @agency = agency
    @departure = departure
    @actor_kind = actor_kind&.to_sym
    @actor = actor
    @actor_identifier = actor_identifier
    @lock_version = lock_version
  end

  def call
    ensure_invocation!
    ensure_departure_actor!(:manage_departures) if agency_user?

    ActiveRecord::Base.transaction do
      if agency_user?
        lock_authorized_agency!(:manage_departures)
      else
        lock_system_agency!
      end
      departure = lock_departure!
      return Result.new(status: :noop, record: departure) if departure.departed?
      ensure_current_lock_version!(departure) if agency_user?

      transitioned_at = Time.current
      unless departure.eligible_to_depart?(at: transitioned_at)
        if agency_user?
          raise Error.new("That departure is not eligible to be marked departed.", code: :invalid_state)
        end

        return Result.new(status: :noop, record: departure)
      end

      prior_status = departure.status
      departure.update!(status: "departed", departed_at: transitioned_at)
      audit!(
        agency: @agency,
        action: "departure.departed",
        subject: departure,
        actor: agency_user? ? @actor : nil,
        actor_identifier: agency_user? ? nil : SYSTEM_ACTOR_IDENTIFIER,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "prior_status" => prior_status,
          "status" => departure.status,
          "starts_on" => departure.starts_on&.iso8601,
          "time_zone" => departure.time_zone,
          "departed_at" => departure.departed_at&.iso8601(6)
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def agency_user?
    @actor_kind == :agency_user
  end

  def ensure_invocation!
    case @actor_kind
    when :agency_user
      if @actor.blank? || @actor_identifier.present?
        raise Error.new("That departed transition invocation is not valid.", code: :invalid)
      end
    when :system
      if @actor.present? || @actor_identifier != SYSTEM_ACTOR_IDENTIFIER
        raise Error.new("That departed transition invocation is not valid.", code: :invalid)
      end
    else
      raise Error.new("That departed transition invocation is not valid.", code: :invalid)
    end
  end
end
