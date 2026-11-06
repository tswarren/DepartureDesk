# Records a trigger event and posts what it makes due (SMN-11 to SMN-14).
# Shared by RecordTriggerEvent and by completing the matching follow-up
# task, so no event is entered twice (SMN-12). The caller holds the
# arrangement lock.
module TriggerEventRecording
  include SupplierAmountPosting

  private

  def record_trigger_event!(departure, arrangement, event_type:, occurred_on:, count: nil, reference: nil)
    raise AgencyCommand::Error.new("Events are recorded once the arrangement is confirmed.", code: :invalid_state) unless arrangement.confirmed?

    date = parse_date(occurred_on, "Event date") or raise AgencyCommand::Error.new("Enter the date it happened.", code: :invalid)
    raise AgencyCommand::Error.new("The event date can't be in the future.", code: :invalid) if date > Clock.current.today_in(@agency.default_timezone)

    number = count.presence && Integer(count.to_s, exception: false)
    raise AgencyCommand::Error.new("Count must be a whole number.", code: :invalid) if count.present? && (number.nil? || number.negative?)

    event = arrangement.trigger_events.create!(agency: @agency, event_type:, occurred_on: date, count: number,
      reference: reference.to_s.strip.presence, recorded_by: @actor, recorded_at: Clock.current.now)
    audit!(agency: @agency, action: "supplier_arrangement.trigger_event_recorded", subject: arrangement, actor: @actor,
      details: { "trigger_event_id" => event.id, "event_type" => event_type, "occurred_on" => date.iso8601, "count" => number }.compact)
    post_amounts_due!(departure, arrangement)
    event
  end
end
