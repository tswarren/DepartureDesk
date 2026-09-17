class CapacityTimelineReplay
  Direction = Struct.new(:sign)

  DIRECTIONS = {
    "established" => Direction.new(1),
    "increased" => Direction.new(1),
    "released" => Direction.new(-1),
    "reinstated" => Direction.new(1),
    "withdrawn" => Direction.new(-1),
    "corrected_up" => Direction.new(1),
    "corrected_down" => Direction.new(-1)
  }.freeze

  Result = Struct.new(:quantity, :events, keyword_init: true)
  NegativeQuantity = Class.new(StandardError)
  InvalidEstablishmentOrder = Class.new(StandardError)

  def initialize(events)
    @events = events
  end

  def call
    ordered = ordered_events
    ensure_established_first!(ordered)

    running_quantity = 0
    ordered.each do |event|
      direction = DIRECTIONS.fetch(event.event_type)
      running_quantity += direction.sign * event.quantity
      if running_quantity.negative?
        raise NegativeQuantity, "capacity timeline cannot become negative"
      end
    end

    Result.new(quantity: running_quantity, events: ordered)
  end

  private

  attr_reader :events

  def ordered_events
    @ordered_events ||= events.sort_by do |event|
      [
        event.effective_on,
        event.effective_sequence,
        event.recorded_at,
        event.id
      ]
    end
  end

  def ensure_established_first!(ordered)
    return if ordered.empty?

    first = ordered.first
    unless first.event_type == "established"
      raise InvalidEstablishmentOrder, "capacity timeline must begin with an established event"
    end

    if ordered.drop(1).any? { |event| event.event_type == "established" }
      raise InvalidEstablishmentOrder, "capacity timeline may contain only one established event"
    end
  end
end
