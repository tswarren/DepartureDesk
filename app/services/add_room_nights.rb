# Adds a hotel's rooms night by night to a draft arrangement (INV-01,
# INV-13): one inventory group per night and room type, labelled "Nov 4
# Garden Queen", for the night from that date to the next. Each night and
# type is on request (no count), a firm count of interchangeable rooms, or
# firm with each room tracked as a unit shell; a night the supplier isn't
# holding is left out. One transaction through SaveInventoryGroup, so a
# refusal adds none.
class AddRoomNights < AgencyCommand
  include ArrangementCommandSupport

  KINDS = %w[skip on_request firm tracked].freeze
  Cell = Data.define(:night, :room_type, :guests, :kind, :count)

  def initialize(agency:, actor:, departure:, arrangement:, cells:, time_zone:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @cells = cells
    @time_zone = time_zone
  end

  def call
    ensure_departure_actor!(:manage_arrangements)
    cells = @cells.reject { |cell| cell.kind == "skip" }
    raise Error.new("Choose at least one night and room type to add.", code: :invalid) if cells.empty?

    ActiveRecord::Base.transaction do
      groups = cells.map do |cell|
        SaveInventoryGroup.new(agency: @agency, actor: @actor, departure: @departure, arrangement: @arrangement, attributes: attributes_for(cell)).call.record
      end
      Result.new(status: :created, record: groups)
    end
  end

  def self.label(night, room_type) = "#{night.strftime("%b %-d")} #{room_type}"

  private

  def attributes_for(cell)
    raise Error.new("#{self.class.label(cell.night, cell.room_type)}: choose on request, firm or tracked.", code: :invalid) unless cell.kind.in?(KINDS)

    base = { label: self.class.label(cell.night, cell.room_type), service_category: "hotel", starts_on: cell.night, ends_on: cell.night + 1, time_zone: @time_zone }
    case cell.kind
    when "on_request" then base.merge(representation: "capacity_pool", availability_promise: "on_request")
    else
      count = Integer(cell.count.to_s, exception: false)
      raise Error.new("#{base[:label]}: enter how many rooms the hotel is holding.", code: :invalid) unless count&.positive?

      raise Error.new("#{base[:label]}: enter the guests per room to track each room.", code: :invalid) if cell.kind == "tracked" && cell.guests.nil?

      if cell.kind == "firm"
        base.merge(representation: "capacity_pool", availability_promise: "firm_block", quantity: count)
      else
        base.merge(representation: "unit_shells", availability_promise: "firm_block", quantity: count, positions_per_unit: cell.guests)
      end
    end
  end
end
