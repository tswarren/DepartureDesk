# Renames, reorders, inactivates or reactivates a traveler type (BKG-21,
# SET-13). Bookings keep the type they were given.
class UpdateTravelerType < AgencyCommand
  def initialize(traveler_type:, actor:, attributes:, lock_version:)
    @traveler_type = traveler_type
    @actor = actor
    @attributes = attributes.to_h.stringify_keys.slice("name", "position", "status", "counts_as_adult")
    @lock_version = lock_version
  end

  def call
    agency = @traveler_type.agency
    status = :noop
    ActiveRecord::Base.transaction do
      agency.with_lock do
        @traveler_type.lock!
        @traveler_type.reload
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_active_agency!(agency)
        raise Error.new("This traveler type was updated by someone else.", code: :conflict) if stale?
        raise Error.new("That status is not available.", code: :invalid) if @attributes.key?("status") && !@attributes["status"].in?(TravelerType::STATUSES)

        @traveler_type.assign_attributes(@attributes)
        changed = @traveler_type.changed - %w[lock_version updated_at]
        next if changed.empty?

        @traveler_type.save!
        status = :updated
        audit!(
          agency:, action: "traveler_type.updated", subject: @traveler_type, actor: @actor,
          details: { "traveler_type_id" => @traveler_type.id, "changed" => changed.sort, "status" => @traveler_type.status }
        )
      end
    end
    Result.new(status:, record: @traveler_type)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    message = error.is_a?(ActiveRecord::RecordNotUnique) || error.record.errors.of_kind?(:name, :taken) ? "That traveler type already exists." : error.record.errors.full_messages.to_sentence
    raise Error.new(message, code: :invalid)
  end

  private

  def stale?
    @lock_version.blank? || @traveler_type.lock_version != @lock_version.to_i
  end
end
