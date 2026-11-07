# Removes a choice with its options and their prices. Nothing books against
# an offering until step 6, which then refuses removal of booked choices.
class RemoveOfferingChoice < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, choice:)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @choice = choice
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      choice = offering.choices.lock.find(@choice.id)
      option_ids = choice.options.pluck(:id)
      OfferingPrice.where(offering_option_id: option_ids).delete_all
      OfferingOption.where(id: option_ids).delete_all
      choice.destroy!
      audit_departure!(departure, "departure.offering_choice_removed", "offering_id" => offering.id, "offering_choice_id" => choice.id, "name" => choice.name)
      Result.new(status: :updated, record: offering)
    end
  end
end
