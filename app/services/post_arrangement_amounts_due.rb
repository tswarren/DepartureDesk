# The sweep's work for one arrangement (SMN-05, SMN-11): records the
# Service date event once the first service date arrives, then posts
# whatever has fallen due. Runs as the system; idempotent.
class PostArrangementAmountsDue < AgencyCommand
  include DepartureCommandSupport
  include SupplierAmountPosting

  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
    @actor = nil
    @actor_identifier = SupplierAmountPosting::SYSTEM_ACTOR_IDENTIFIER
  end

  def call
    ActiveRecord::Base.transaction do
      lock_system_agency!
      departure = @agency.departures.lock.find(@arrangement.departure_id)
      arrangement = departure.supplier_arrangements.lock.find(@arrangement.id)
      return Result.new(status: :noop, record: arrangement) unless arrangement.confirmed?

      record_service_date!(arrangement)
      posted = post_amounts_due!(departure, arrangement)
      Result.new(status: posted.any? ? :updated : :noop, record: arrangement)
    end
  end

  private

  def record_service_date!(arrangement)
    first = arrangement.inventory_groups.minimum(:starts_on)
    return if first.nil? || first > Clock.current.today_in(@agency.default_timezone)
    return if arrangement.trigger_events.exists?(event_type: "service_date")

    event = arrangement.trigger_events.create!(agency: @agency, event_type: "service_date", occurred_on: first,
      recorded_by_identifier: @actor_identifier, recorded_at: Clock.current.now)
    audit!(agency: @agency, action: "supplier_arrangement.trigger_event_recorded", subject: arrangement, actor_identifier: @actor_identifier,
      details: { "trigger_event_id" => event.id, "event_type" => "service_date", "occurred_on" => first.iso8601 })
  end
end
