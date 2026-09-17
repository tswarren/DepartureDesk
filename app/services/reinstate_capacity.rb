class ReinstateCapacity < AgencyCommand
  include CapacityCommandSupport

  def initialize(
    agency:,
    actor:,
    projection_lock_version:,
    idempotency_key:,
    attributes:,
    releases: nil,
    release_event: nil,
    quantity: nil,
    recorded_at: nil,
    effective_on: nil,
    effective_sequence: nil
  )
    @agency = agency
    @actor = actor
    @projection_lock_version = projection_lock_version
    @idempotency_key = idempotency_key
    @attributes = attributes
    @releases = releases
    @release_event = release_event
    @quantity = quantity
    @recorded_at = recorded_at
    @effective_on = effective_on
    @effective_sequence = effective_sequence
  end

  def call
    release_specs = normalized_release_specs
    pool = release_specs.first.fetch(:reinstates_event).capacity_pool
    unless release_specs.all? { |spec| spec.fetch(:reinstates_event).capacity_pool_id == pool.id }
      raise Error.new("All reinstated releases must belong to the same capacity pool.", code: :invalid)
    end

    result = record_capacity_events!(
      pool: pool,
      specs: release_specs.map do |spec|
        {
          event_type: "reinstated",
          quantity: spec.fetch(:quantity),
          effective_on: @effective_on,
          effective_sequence: release_specs.one? ? @effective_sequence : nil,
          reinstates_event: spec.fetch(:reinstates_event)
        }
      end,
      recorded_at: @recorded_at,
      projection_lock_version: @projection_lock_version,
      idempotency_key: @idempotency_key,
      attributes: @attributes
    )

    if release_specs.one?
      AgencyCommand::Result.new(status: result.status, record: Array(result.record).first)
    else
      result
    end
  end

  private

  def normalized_release_specs
    if @releases.present?
      Array(@releases).map do |entry|
        entry = entry.to_h.with_indifferent_access
        release = entry[:release_event] || entry[:event] || @agency.capacity_events.find(entry.fetch(:release_event_id))
        release = @agency.capacity_events.find(release.id)
        {
          reinstates_event: release,
          quantity: entry.fetch(:quantity)
        }
      end
    elsif @release_event.present?
      release = @agency.capacity_events.find(@release_event.id)
      [ { reinstates_event: release, quantity: @quantity } ]
    else
      raise Error.new("Enter at least one release to reinstate.", code: :invalid)
    end
  end
end
