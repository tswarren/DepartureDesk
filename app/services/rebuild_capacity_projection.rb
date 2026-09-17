class RebuildCapacityProjection < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, pool:, now: Time.current)
    @agency = agency
    @pool = pool
    @now = now
  end

  def call
    ActiveRecord::Base.transaction do
      lock_system_agency!
      departure, arrangement, version, _item, _occurrence, _resource, _supplier, pool = lock_capacity_event_graph!(@pool)
      ensure_activated_capacity_graph!(departure, arrangement, version)
      ensure_numeric_capacity_pool!(pool)
      ensure_capacity_pool_established!(pool)

      projection = pool.capacity_projection
      raise Error.new("Capacity projection is missing.", code: :invalid_state) if projection.nil?

      projection.lock!
      refresh_capacity_projection_state!(pool, projection, @now)
      projection.update!(rebuilt_at: @now) if projection.rebuilt_at != @now
      AgencyCommand::Result.new(status: :updated, record: projection.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
