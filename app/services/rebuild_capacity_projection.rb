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
      pool = @agency.capacity_pools.lock.find(@pool.id)
      ensure_numeric_capacity_pool!(pool)
      projection = pool.capacity_projection || build_initial_capacity_projection(pool, @now)
      projection.lock! unless projection.new_record?
      refresh_capacity_projection_state!(pool, projection, @now)
      projection.update!(rebuilt_at: @now) if projection.rebuilt_at != @now
      AgencyCommand::Result.new(status: :updated, record: projection.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
