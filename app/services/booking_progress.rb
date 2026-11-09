# The booking workspace's four steps (S-26): travelers, rooms and options,
# price and hold, then acceptance and confirmation. Each step's state comes
# from the booking and what still blocks confirmation (BKG-45); the page
# opens on the first step not yet done. Nothing here changes a booking.
class BookingProgress
  STEPS = %w[travelers rooms price confirm].freeze
  LABELS = { "travelers" => "Travelers", "rooms" => "Rooms and options", "price" => "Price and hold", "confirm" => "Accept and confirm" }.freeze

  Step = Data.define(:key, :number, :label, :done, :note)

  # The step that shows a workspace section, by its anchor.
  def self.step_for(anchor)
    case anchor.to_s
    when "travelers", /\Abooking-traveler-/ then "travelers"
    when "choices", /\Achoice-/, "supplier-requests" then "rooms"
    when "prices", "hold", "installments" then "price"
    else "confirm"
    end
  end

  def initialize(booking, blockers)
    @booking = booking
    @blockers = blockers
  end

  def steps
    @steps ||= STEPS.each_with_index.map { |key, index| Step.new(key:, number: index + 1, label: LABELS.fetch(key), done: done?(key), note: note(key)) }
  end

  # The first step not done, or the last once the booking has left Draft.
  def current
    return "confirm" unless @booking.status_draft?

    steps.find { |step| !step.done }&.key || "confirm"
  end

  def next_after(key) = STEPS[STEPS.index(key) + 1]

  private

  def done?(key)
    case key
    when "travelers" then @booking.booking_travelers.any?
    when "rooms" then @booking.choice_selections.any? && blocked_in?("rooms").empty?
    when "price" then held? && blocked_in?("price").empty?
    else !@booking.status_draft?
    end
  end

  def note(key)
    case key
    when "travelers"
      count = @booking.booking_travelers.size
      count.zero? ? "Not started" : "#{count} added"
    when "rooms"
      return "Not started" if @booking.choice_selections.empty?

      (gaps = blocked_in?("rooms").size).zero? ? "Done" : "#{gaps} to do"
    when "price"
      return "Reserved" if @booking.inventory_allocations.any?(&:state_reserved?)

      held? ? "Held" : "Not held"
    else
      if @booking.status_confirmed? then "Confirmed"
      elsif !@booking.status_draft? then @booking.status.humanize
      elsif @booking.current_acceptance then "Accepted"
      else "After the hold"
      end
    end
  end

  def held?
    state, = @booking.hold_state
    state == :held || @booking.inventory_allocations.any?(&:state_reserved?)
  end

  def blocked_in?(key) = @blockers.select { |blocker| self.class.step_for(blocker.anchor) == key }
end
