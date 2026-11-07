# Links a traveler to a client with a relationship (CLT-09), or removes the
# link. A link is a convenience and grants nothing (CLT-10).
class LinkTraveler < AgencyCommand
  include TravelerCommandSupport

  def initialize(agency:, actor:, client:, traveler_id:, relationship:)
    @agency = agency
    @actor = actor
    @client = client
    @traveler_id = traveler_id
    @relationship = relationship.to_s.presence
  end

  def call
    ensure_actor!(:manage_client_directory)

    ActiveRecord::Base.transaction do
      @agency.lock!
      client = active_client!(@client.id)
      traveler = @agency.travelers.find_by(id: @traveler_id)
      raise Error.new("Traveler must be chosen.", code: :invalid) if traveler.nil?
      raise Error.new("Relationship must be chosen.", code: :invalid) unless @relationship.in?(TravelerLink::RELATIONSHIPS)

      Result.new(status: :created, record: link_traveler!(client, traveler, @relationship))
    end
  rescue ActiveRecord::RecordInvalid => error
    invalid!(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("Relationship Self is already used for this client's own traveler.", code: :invalid)
  end
end
