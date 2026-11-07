# What a booking still needs before it can be confirmed (BKG-45, BKG-39,
# CLT-15, D16), each item with the place on the booking workspace that
# fixes it.
class BookingConfirmationCheck
  include BookingCommandSupport

  Blocker = Data.define(:message, :anchor)

  def initialize(booking)
    @booking = booking
    @agency = booking.agency
  end

  def blockers
    list = []
    list.concat(acceptance_blockers)
    departure = @booking.departure
    list << Blocker.new(message: "#{departure.name} isn't on sale.", anchor: "status") unless departure.on_sale?
    @booking.offering.booking_blockers.each { |message| list << Blocker.new(message:, anchor: "choices") }
    list.concat(traveler_blockers)
    list.concat(choice_blockers)
    occupancy_problems(@booking).each { |message| list << Blocker.new(message:, anchor: "choices") }
    list.concat(hold_blockers)
    list.concat(rate_blockers)
    list
  end

  private

  # BKG-39, BKG-28: acceptance of the current price and terms.
  def acceptance_blockers
    terms = @booking.client_terms_version
    return [ Blocker.new(message: "The Departure has no client terms for this booking yet.", anchor: "status") ] if terms.nil?

    list = terms.booking_blockers.map { |message| Blocker.new(message: "Client terms: #{message}", anchor: "status") }
    return list if @booking.current_acceptance

    message = if @booking.latest_acceptance
      "The recorded acceptance no longer covers the current price and terms; record the client's acceptance again."
    else
      "Record the client's acceptance of the current price and terms."
    end
    list << Blocker.new(message:, anchor: "acceptance")
  end

  # SUP-35: each unit drawn from a rate table needs a rate for its occupancy.
  def rate_blockers
    @booking.choice_selections.select(&:per_unit?).filter_map do |selection|
      next if selection.inventory_group.rate_lines.empty? || selection.occupants.none?(&:position)

      missing = supplier_proposal(@booking, selection).missing
      next if missing.empty?

      positions = missing.map { |position| OfferingPrice::POSITION_LABELS.fetch(position).downcase }.to_sentence
      Blocker.new(message: "The supplier rate table has no #{positions} rate for #{selection.label}.", anchor: "choices")
    end
  end

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
    active.group_by(&:inventory_group).each do |group, allocations|
      capacity = GroupCapacity.new(group:)
      if capacity.conflict?
        blockers << Blocker.new(message: "The supplier reduced space below what this booking holds; resolve it before confirming.", anchor: "hold")
        next
      end
      # Confirmed space is kept for good, so it must fit every supply point ahead (INV-23).
      reserved = allocations.select(&:state_held?).map { |allocation| GroupCapacity::Projected.from(allocation, state: "reserved") }
      next unless capacity.shortfall(capacity.project(changed: reserved))

      blockers << Blocker.new(message: "#{group.label} has a supply reduction scheduled that confirming this booking would exceed; resolve it before confirming.", anchor: "hold")
    end
    blockers.uniq
  end
end
