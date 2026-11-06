# Removes one client price from an option.
class RemoveOfferingPrice < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, price:)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @price = price
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      price = OfferingPrice.joins(option: :choice).where(offering_choices: { offering_id: offering.id }).lock.find(@price.id)
      price.destroy!
      audit_departure!(departure, "departure.offering_price_removed", "offering_price_id" => price.id, "offering_option_id" => price.offering_option_id)
      Result.new(status: :updated, record: offering)
    end
  end
end
