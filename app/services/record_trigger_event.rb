# Records an event a schedule line can fall due on, from the arrangement
# (SMN-11 to SMN-14), and posts what it makes due.
class RecordTriggerEvent < AgencyCommand
  include ArrangementCommandSupport
  include TriggerEventRecording

  def initialize(agency:, actor:, departure:, arrangement:, event_type:, occurred_on:, count: nil, reference: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @event_type = event_type.to_s
    @occurred_on = occurred_on
    @count = count
    @reference = reference
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    raise Error.new("Choose an event staff record.", code: :invalid) unless TriggerEvent::STAFF_TYPES.include?(@event_type)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      event = record_trigger_event!(departure, arrangement, event_type: @event_type, occurred_on: @occurred_on, count: @count, reference: @reference)
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
