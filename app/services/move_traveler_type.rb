# Moves a traveler type one place up or down the agency's list (BKG-21,
# SET-13) by renumbering the list in order.
class MoveTravelerType < AgencyCommand
  DIRECTIONS = %w[up down].freeze

  def initialize(traveler_type:, actor:, direction:)
    @traveler_type = traveler_type
    @actor = actor
    @direction = direction.to_s
  end

  def call
    raise Error.new("Choose up or down.", code: :invalid) unless @direction.in?(DIRECTIONS)

    agency = @traveler_type.agency
    status = :noop
    ActiveRecord::Base.transaction do
      agency.with_lock do
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_active_agency!(agency)
        ordered = agency.traveler_types.ordered.lock.to_a
        index = ordered.index { |traveler_type| traveler_type.id == @traveler_type.id }
        target = @direction == "up" ? index - 1 : index + 1
        next if target.negative? || target >= ordered.size

        ordered[index], ordered[target] = ordered[target], ordered[index]
        ordered.each_with_index { |traveler_type, position| traveler_type.update!(position:) if traveler_type.position != position }
        status = :updated
        audit!(
          agency:, action: "traveler_type.updated", subject: @traveler_type, actor: @actor,
          details: { "traveler_type_id" => @traveler_type.id, "changed" => [ "position" ], "order" => ordered.map(&:id) }
        )
      end
    end
    Result.new(status:, record: @traveler_type.reload)
  end
end
