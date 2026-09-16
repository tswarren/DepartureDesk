class MarkDepartureDepartedJob < ApplicationJob
  queue_as :departures

  retry_on ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure, ActiveRecord::LockWaitTimeout,
    attempts: 5, wait: :polynomially_longer

  def perform(agency_id:, departure_id:)
    agency = Agency.find_by(id: agency_id)
    return if agency.nil? || !agency.active?

    departure = agency.departures.find_by(id: departure_id)
    return if departure.nil?

    MarkDepartureDeparted.new(
      agency:,
      departure:,
      actor_kind: :system,
      actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
    ).call
  rescue AgencyCommand::Error => error
    if %i[invalid unauthorized].include?(error.code)
      Rails.logger.error({
        event: "mark_departure_departed_job.unexpected_command_error",
        agency_id:,
        departure_id:,
        job_id:,
        error_code: error.code
      }.to_json)
    end
    raise unless %i[invalid invalid_state unauthorized conflict].include?(error.code)
  end
end
