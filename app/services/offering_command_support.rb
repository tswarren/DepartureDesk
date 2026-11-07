# Shared steps for offering and client terms commands (BKG-13 to BKG-16,
# BKG-21, BKG-28). Editing needs Departure management. Lock order: agency,
# Departure, then the offering or terms version. A Departed Departure is
# read-only (DEP-43).
module OfferingCommandSupport
  include DepartureCommandSupport

  private

  def lock_offering_context!
    lock_authorized_agency!(:manage_departures)
    departure = lock_departure!
    raise AgencyCommand::Error.new("A departed departure's package and terms cannot change.", code: :invalid_state) if departure.departed?

    departure
  end

  def lock_offering!(departure)
    departure.offerings.lock.find(@offering.id)
  end

  def ensure_version!(record)
    raise AgencyCommand::Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || record.lock_version != @lock_version.to_i
  end

  def clean(attributes, fields)
    attributes.to_h.stringify_keys.slice(*fields).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
  end

  def audit_departure!(departure, action, details)
    audit!(agency: @agency, action:, subject: departure, actor: @actor, details:)
  end
end
