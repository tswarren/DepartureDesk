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

  def initialize(events)
    @events = events
  end

  def call
    running_quantity = 0
    ordered_events.each do |event|
      direction = DIRECTIONS.fetch(event.event_type)
      running_quantity += direction.sign * event.quantity
      if running_quantity.negative?
        raise NegativeQuantity, "capacity timeline cannot become negative"
      end
    end

    Result.new(quantity: running_quantity, events: ordered_events)
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
end
