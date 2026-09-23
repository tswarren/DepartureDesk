class RefreshDueCapacityProjection < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, pool:, now: Time.current)
    @agency = agency
    @pool = pool
    @now = now
  end

  def call
    ActiveRecord::Base.transaction do
      lock_system_agency!
      begin
        _departure, arrangement, version, _item, _occurrence, _resource, _supplier, pool =
          lock_capacity_event_graph!(@pool)
      rescue ActiveRecord::RecordNotFound
        return AgencyCommand::Result.new(status: :noop, record: nil)
      end

      return AgencyCommand::Result.new(status: :noop, record: nil) unless pool.numeric_inventory?

      projection = pool.capacity_projection
      return AgencyCommand::Result.new(status: :noop, record: nil) if projection.nil?

      projection.lock!
      refresh_capacity_projection_state!(pool, projection, @now)
      result = AgencyCommand::Result.new(status: :updated, record: projection.reload)
      actor = projection.last_event&.actor
      if actor.present?
        governing = arrangement.governing_version || version
        ReevaluateQuantityDerivedDepositCumulativeAlreadyLocked.new(
          agency: @agency,
          actor:,
          arrangement:,
          version: governing,
          at: @now
        ).call(pool_ids: [ pool.id ])
      end
      result
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
