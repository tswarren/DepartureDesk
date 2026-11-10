# The booking workspace's pages (S-26): a read-only Summary, the five steps
# (travelers, rooms and options, price and installments, hold space, then
# acceptance and confirmation), and, once the booking has a client charge,
# its Money (UX consolidation audit B2, A6, decisions 4 and 7). Each step's
# state comes from the booking and what still blocks confirmation (BKG-45).
# A draft opens on the first step not yet done; any other booking opens on
# its Summary. Nothing here changes a booking.
class BookingProgress
  STEPS = %w[summary travelers rooms price hold confirm money].freeze
  NUMBERED = %w[travelers rooms price hold confirm].freeze
  LABELS = {
    "summary" => "Summary", "travelers" => "Travelers", "rooms" => "Rooms and options", "price" => "Price and installments",
    "hold" => "Hold space", "confirm" => "Accept and confirm", "money" => "Money"
  }.freeze

  Step = Data.define(:key, :number, :label, :done, :note)

  # The step that shows a workspace section, by its anchor.
  def self.step_for(anchor)
    case anchor.to_s
    when "travelers", /\Abooking-traveler-/ then "travelers"
    when "choices", /\Achoice-/, "supplier-requests" then "rooms"
    when "prices", "installments" then "price"
    when "hold" then "hold"
    when "booking-payments" then "money"
    else "confirm"
    end
  end

  def initialize(booking, blockers)
    @booking = booking
    @blockers = blockers
  end

  def steps
    @steps ||= available.map do |key|
      number = NUMBERED.index(key)&.succ
      Step.new(key:, number:, label: LABELS.fetch(key), done: number ? done?(key) : false, note: note(key))
    end
  end

  def available = STEPS.select { |key| key != "money" || @booking.client_charge }

  # The first step not done on a draft; the Summary once it has left Draft.
  def current
    return "summary" unless @booking.status_draft?

    steps.find { |step| step.number && !step.done }&.key || "confirm"
  end

  # The step after this one, among the numbered steps and Money.
  def next_after(key)
    return if key == "summary"

    following = available.drop_while { |step| step != key }.drop(1)
    following.first
  end

  private

  def done?(key)
    case key
    when "travelers" then @booking.booking_travelers.any?
    when "rooms" then @booking.choice_selections.any? && blocked_in?("rooms").empty?
    when "price" then @booking.price_lines.any? && blocked_in?("price").empty?
    when "hold" then held? && blocked_in?("hold").empty?
    else !@booking.status_draft?
    end
  end

  def note(key)
    case key
    when "summary" then "The whole booking"
    when "travelers"
      count = @booking.booking_travelers.size
      count.zero? ? "Not started" : "#{count} added"
    when "rooms"
      return "Not started" if @booking.choice_selections.empty?

      (gaps = blocked_in?("rooms").size).zero? ? "All placed" : "#{gaps} to do"
    when "price"
      return "After rooms" if @booking.price_lines.empty?

      @booking.client_charge ? "Charged" : "Proposed"
    when "hold"
      return "Reserved" if @booking.inventory_allocations.any?(&:state_reserved?)

      held? ? "Held" : "Not held"
    when "confirm"
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
