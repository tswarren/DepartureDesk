# Creates or renames a Departure's package offering (BKG-13). Its currency
# is the Departure's operating currency (FIN-22).
class SaveOffering < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, offering: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @attributes = clean(attributes, %w[name description])
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = if @offering
        lock_offering!(departure).tap { |record| ensure_version!(record) }
      else
        raise Error.new("Set the departure's operating currency before adding a package.", code: :invalid_state) if departure.operating_currency.blank?

        departure.offerings.new(agency: @agency, currency: departure.operating_currency, position: departure.offerings.maximum(:position).to_i + 1)
      end
      creating = offering.new_record?
      offering.assign_attributes(@attributes.slice("name", "description"))
      changed = offering.changed - %w[lock_version updated_at currency position]
      return Result.new(status: :noop, record: offering) if !creating && changed.empty?

      offering.save!
      audit_departure!(departure, creating ? "departure.offering_created" : "departure.offering_updated",
        "offering_id" => offering.id, "name" => offering.name, "changed" => changed.sort)
      Result.new(status: creating ? :created : :updated, record: offering)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("This departure already has a package with that name.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
