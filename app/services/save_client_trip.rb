# Creates a Client Trip for one responsible client (CLT-02), on at most one
# Departure (OVR-02), with its reference issued at creation (REF-04, D-94),
# or changes its Departure. The responsible client is fixed once the trip
# exists. A reseller user creates a trip only for a client its users
# created, while creating that client's booking (CLT-25).
class SaveClientTrip < AgencyCommand
  include TravelerCommandSupport
  include ReferenceIssuance

  def initialize(agency:, actor:, attributes:, trip: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @trip = trip
    @attributes = clean(attributes, %w[client_id departure_id])
    @lock_version = lock_version
  end

  def call
    if reseller_actor?
      ensure_reseller_actor!(:reseller_manage_bookings)
      ensure_active_agency!(@agency)
      raise Error.new(UNAUTHORIZED, code: :unauthorized) if @trip || !ResellerScope.new(@actor).clients.exists?(id: @attributes["client_id"])
    else
      ensure_actor!(:manage_bookings)
    end

    ActiveRecord::Base.transaction do
      @agency.lock!
      trip = if @trip
        @agency.client_trips.lock.find(@trip.id).tap { |record| ensure_version!(record) }
      else
        @agency.client_trips.new(client: active_client!(@attributes["client_id"]))
      end
      creating = trip.new_record?
      trip.departure = departure
      changed = trip.changed - %w[lock_version updated_at client_id]
      return Result.new(status: :noop, record: trip) if !creating && changed.empty?

      trip.trip_reference = issue_reference!(@agency, ReferenceSequence::TRIP_NAMESPACE) if creating
      trip.save!
      audit!(agency: @agency, action: creating ? "client_trip.created" : "client_trip.updated", subject: trip, actor: @actor,
        details: { "client_trip_id" => trip.id, "trip_reference" => trip.trip_reference, "client_id" => trip.client_id, "departure_id" => trip.departure_id })
      Result.new(status: creating ? :created : :updated, record: trip)
    end
  rescue ActiveRecord::RecordInvalid => error
    invalid!(error)
  end

  private

  def departure
    return if @attributes["departure_id"].blank?

    @agency.departures.find_by(id: @attributes["departure_id"]) || raise(Error.new("Departure must be one of this agency's.", code: :invalid))
  end
end
