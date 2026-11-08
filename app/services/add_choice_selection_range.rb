# Adds one room type over a range of nights to a draft booking: one unit of
# each night's option, with the same occupants (BKG-14, question 19). One
# transaction, through SaveChoiceSelection for each night, so a refusal on
# any night adds none.
class AddChoiceSelectionRange < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, attributes:)
    @agency = agency
    @actor = actor
    @booking = booking
    attributes = attributes.to_h.stringify_keys
    @choice_id = attributes["choice_id"]
    @kind = attributes["kind"].to_s
    @from = parse_date(attributes["from"])
    @through = parse_date(attributes["through"])
    @occupant_ids = Array(attributes["occupant_ids"]).compact_blank
  end

  def call
    ensure_actor!
    raise Error.new("Choose the first and last night.", code: :invalid) unless @from && @through
    raise Error.new("The last night must be on or after the first.", code: :invalid) if @through < @from

    choice = @booking.offering.choices.find { |candidate| candidate.id == @choice_id } or raise Error.new("Choice must be one of this package's.", code: :invalid)
    options = choice.options.select { |option| option.night_kind == @kind && (@from..@through).cover?(option.inventory_group.starts_on) }
      .sort_by { |option| option.inventory_group.starts_on }
    raise Error.new("No #{@kind} night falls in that range.", code: :invalid) if options.empty?

    ActiveRecord::Base.transaction do
      records = options.map do |option|
        SaveChoiceSelection.new(agency: @agency, actor: @actor, booking: @booking,
          attributes: { offering_option_id: option.id, occupant_ids: @occupant_ids }).call.record
      end
      Result.new(status: :created, record: records)
    end
  end

  private

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
