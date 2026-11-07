# Removes an option with its prices.
class RemoveOfferingOption < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, option:)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @option = option
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      option = OfferingOption.joins(:choice).where(offering_choices: { offering_id: offering.id }).lock.find(@option.id)
      raise Error.new("Bookings use #{option.label}, so it can't be removed.", code: :invalid_state) if option.choice_selections.exists?
      option.prices.delete_all(:delete_all)
      option.destroy!
      audit_departure!(departure, "departure.offering_option_removed", "offering_id" => offering.id, "offering_option_id" => option.id, "label" => option.label)
      Result.new(status: :updated, record: offering)
    end
  end
end
