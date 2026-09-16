class MarkEligibleDeparturesDepartedJob < ApplicationJob
  queue_as :departures

  BATCH_SIZE = 100

  def perform
    observed_at = Time.current
    cursor = nil
    loop do
      rows = next_batch(cursor, at: observed_at)
      break if rows.empty?

      rows.each do |agency_id, departure_id, _starts_on|
        MarkDepartureDepartedJob.perform_later(agency_id:, departure_id:)
      end
      break if rows.size < BATCH_SIZE

      last = rows.last
      cursor = [ last[0], last[2], last[1] ]
    end
  end

  private

  def next_batch(cursor, at:)
    relation = Departure.eligible_to_depart_relation(at:)
    if cursor
      agency_id, starts_on, id = cursor
      relation = relation.where(
        "(departures.agency_id, departures.starts_on, departures.id) > (?, ?, ?)",
        agency_id, starts_on, id
      )
    end

    relation.order("departures.agency_id", "departures.starts_on", "departures.id")
      .limit(BATCH_SIZE)
      .pluck("departures.agency_id", "departures.id", "departures.starts_on")
  end
end
