# Adds rooms over a range of nights to a draft booking: for each room, one
# unit of each night's option of its room type, with that room's occupants
# (BKG-14, question 19). Staff give one room, or the booking's rooms of an
# included hotel room choice, each keeping its type and travelers. One
# transaction, through SaveChoiceSelection for each night, so a refusal on
# any night adds none.
class AddChoiceSelectionRange < AgencyCommand
  include BookingCommandSupport
  allow_reseller_actor

  def initialize(agency:, actor:, booking:, attributes:)
    @agency = agency
    @actor = actor
    @booking = booking
    attributes = attributes.to_h.stringify_keys
    @choice_id = attributes["choice_id"]
    @from = parse_date(attributes["from"])
    @through = parse_date(attributes["through"])
    @rooms = rooms_from(attributes)
  end

  def call
    ensure_actor!
    raise Error.new("Choose the first and last night.", code: :invalid) unless @from && @through
    raise Error.new("The last night must be on or after the first.", code: :invalid) if @through < @from

    choice = @booking.offering.choices.find { |candidate| candidate.id == @choice_id } or raise Error.new("Choice must be one of this package's.", code: :invalid)
    raise Error.new("Choose a room.", code: :invalid) if @rooms.empty?

    plans = @rooms.map do |kind, occupant_ids|
      options = choice.options.select { |option| option.night_kind == kind && (@from..@through).cover?(option.inventory_group.starts_on) }
        .sort_by { |option| option.inventory_group.starts_on }
      raise Error.new("No #{kind} night falls in that range.", code: :invalid) if options.empty?

      [ options, occupant_ids ]
    end

    ActiveRecord::Base.transaction do
      records = plans.flat_map do |options, occupant_ids|
        options.map do |option|
          SaveChoiceSelection.new(agency: @agency, actor: @actor, booking: @booking,
            attributes: { offering_option_id: option.id, occupant_ids: }).call.record
        end
      end
      Result.new(status: :created, record: records)
    end
  end

  private

  # [[room type, occupant ids], ...]: the rooms given, or the one room.
  def rooms_from(attributes)
    rooms = attributes["rooms"]
    rooms = rooms.values if rooms.is_a?(Hash)
    if attributes["mode"] == "rooms" && rooms.present?
      Array(rooms).map { |room| room.to_h.stringify_keys }.map { |room| [ room["kind"].to_s, Array(room["occupant_ids"]).compact_blank ] }
        .reject { |kind, _| kind.blank? }
    else
      kind = attributes["kind"].to_s
      kind.present? ? [ [ kind, Array(attributes["occupant_ids"]).compact_blank ] ] : []
    end
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
