# Adds a traveler type to the end of the agency's list (BKG-21, SET-13).
class CreateTravelerType < AgencyCommand
  def initialize(agency:, actor:, name:)
    @agency = agency
    @actor = actor
    @name = name
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_active_agency!(@agency)
        position = (@agency.traveler_types.maximum(:position) || -1) + 1
        traveler_type = @agency.traveler_types.create!(name: @name, position:)
        audit!(
          agency: @agency, action: "traveler_type.created", subject: traveler_type, actor: @actor,
          details: { "traveler_type_id" => traveler_type.id, "name" => traveler_type.name }
        )
        Result.new(status: :created, record: traveler_type)
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    raise Error.new(traveler_type_message(error), code: :invalid)
  end

  private

  def traveler_type_message(error)
    return "That traveler type already exists." if error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.of_kind?(:name, :taken)

    error.record.errors.full_messages.to_sentence
  end
end
