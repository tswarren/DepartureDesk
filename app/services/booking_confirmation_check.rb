# What a booking still needs before it can be confirmed (BKG-45, CLT-15,
# D16), each item with the place on the booking workspace that fixes it.
# Acceptance arrives in build step 6c; until then every booking lists it.
class BookingConfirmationCheck
  include BookingCommandSupport

  Blocker = Data.define(:message, :anchor)

  def initialize(booking)
    @booking = booking
    @agency = booking.agency
  end

  def blockers
    list = []
    list << Blocker.new(message: "Record the client's acceptance of the current price and terms.", anchor: "acceptance")
    departure = @booking.departure
    list << Blocker.new(message: "#{departure.name} isn't on sale.", anchor: "status") unless departure.on_sale?
    @booking.offering.booking_blockers.each { |message| list << Blocker.new(message:, anchor: "choices") }
    list.concat(traveler_blockers)
    list.concat(choice_blockers)
    occupancy_problems(@booking).each { |message| list << Blocker.new(message:, anchor: "choices") }
    list.concat(hold_blockers)
    list
  end

  private

  def traveler_blockers
    travelers = @booking.booking_travelers
    return [ Blocker.new(message: "Add the travelers.", anchor: "travelers") ] if travelers.empty?

    travelers.filter_map do |traveler|
      anchor = "booking-traveler-#{traveler.id}"
      if traveler.placeholder?
        Blocker.new(message: "Replace #{traveler.placeholder_label} with a traveler who has a legal name and date of birth.", anchor:)
      elsif !traveler.named_for_confirmation?
        Blocker.new(message: "Enter #{traveler.display_name}'s legal name and date of birth.", anchor:)
      end
    end
  end

  def choice_blockers
    selections = @booking.choice_selections
    @booking.offering.choices.select(&:required_single?).flat_map do |choice|
      chosen = selections.select { |selection| selection.choice.id == choice.id }
      anchor = "choice-#{choice.id}"
      next [ Blocker.new(message: "Choose #{choice.name.downcase}.", anchor:) ] if chosen.empty?

      placed = chosen.flat_map { |selection| selection.occupants.map(&:booking_traveler_id) }
      @booking.booking_travelers.reject { |traveler| placed.include?(traveler.id) }.map do |traveler|
        Blocker.new(message: "Place #{traveler.display_name} in #{choice.made_per_unit? ? "a #{choice.name.downcase}" : choice.name.downcase}.", anchor:)
      end
    end
  end

  def hold_blockers
    needs = allocation_needs(@booking)
    return [] if needs.empty?

    active = @booking.consuming_allocations
    return [ Blocker.new(message: "Hold space for the booking.", anchor: "hold") ] if active.empty?

    blockers = []
    if needs.map { |need| need_signature(need) }.sort != active.map { |allocation| allocation_signature(allocation) }.sort
      blockers << Blocker.new(message: "The hold doesn't match the booking; hold space again.", anchor: "hold")
    end
    if active.map(&:inventory_group).uniq.any? { |group| GroupCapacity.new(group:).conflict? }
      blockers << Blocker.new(message: "The supplier reduced space below what this booking holds; resolve it before confirming.", anchor: "hold")
    end
    blockers
  end
end
