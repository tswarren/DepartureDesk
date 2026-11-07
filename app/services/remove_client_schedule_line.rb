# Removes a line from an unlocked client payment schedule template.
class RemoveClientScheduleLine < AgencyCommand
  include ClientTermsCommandSupport

  def initialize(agency:, actor:, departure:, terms_version:, line:)
    @agency = agency
    @actor = actor
    @departure = departure
    @terms_version = terms_version
    @line = line
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      version = lock_terms_version!(departure)
      line = version.schedule_lines.lock.find(@line.id)
      line.destroy!
      audit_departure!(departure, "departure.client_schedule_line_removed", "client_terms_version_id" => version.id, "client_payment_schedule_line_id" => line.id)
      Result.new(status: :updated, record: version)
    end
  end
end
