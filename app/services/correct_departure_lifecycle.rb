class CorrectDepartureLifecycle < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, reason:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @reason = reason
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      ensure_current_lock_version!(departure)
      unless departure.departed?
        raise Error.new("Only a departed departure can receive a lifecycle correction.", code: :invalid_state)
      end
      reason = normalize_reason(@reason)

      transitioned_at = Time.current
      unless departure.lifecycle_correction_allowed?(at: transitioned_at)
        raise Error.new("That departure cannot return to active because its start date is not in the future.", code: :invalid_state)
      end

      prior_status = departure.status
      departure.update!(status: "active", departed_at: nil)
      audit!(
        agency: @agency,
        action: "departure.lifecycle_corrected",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "reason" => reason,
          "prior_status" => prior_status,
          "status" => departure.status,
          "departed_at" => nil
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
