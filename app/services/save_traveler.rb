# Creates or edits a traveler profile (CLT-05, CLT-06, CLT-28). A profile
# saves with details missing; only a name is needed to find it. When created
# from a client's profile it is linked to that client (CLT-09).
class SaveTraveler < AgencyCommand
  include TravelerCommandSupport

  def initialize(agency:, actor:, attributes:, traveler: nil, lock_version: nil, link_client: nil, relationship: nil)
    @agency = agency
    @actor = actor
    @traveler = traveler
    @attributes = clean(attributes, TRAVELER_FIELDS)
    @lock_version = lock_version
    @link_client = link_client
    @relationship = relationship.presence
  end

  def call
    ensure_actor!(:manage_client_directory)

    ActiveRecord::Base.transaction do
      @agency.lock!
      traveler = @traveler ? @agency.travelers.lock.find(@traveler.id).tap { |record| ensure_version!(record) } : @agency.travelers.new(created_by: @actor)
      creating = traveler.new_record?
      traveler.assign_attributes(@attributes.merge(date_attribute))
      changed = traveler.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: traveler) if !creating && changed.empty?

      traveler.save!
      audit!(agency: @agency, action: creating ? "traveler.created" : "traveler.updated", subject: traveler, actor: @actor,
        details: { "traveler_id" => traveler.id, "changed_fields" => changed.sort })
      link_traveler!(active_client!(@link_client.id), traveler, @relationship || "other") if creating && @link_client
      Result.new(status: creating ? :created : :updated, record: traveler)
    end
  rescue ActiveRecord::RecordInvalid => error
    invalid!(error)
  end

  private

  # A date that doesn't parse is refused, never saved as blank.
  def date_attribute
    return {} unless @attributes.key?("date_of_birth")

    value = @attributes["date_of_birth"]
    return { "date_of_birth" => value } unless value.is_a?(String)

    { "date_of_birth" => Date.iso8601(value) }
  rescue Date::Error
    raise Error.new("Date of birth must be a date, such as 2016-02-08.", code: :invalid)
  end
end
