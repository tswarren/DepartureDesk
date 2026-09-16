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
      pool = @agency.capacity_pools.lock.find(@pool.id)
      return AgencyCommand::Result.new(status: :noop, record: nil) unless pool.numeric_inventory?

      projection = pool.capacity_projection
      return AgencyCommand::Result.new(status: :noop, record: nil) if projection.nil?

      projection.lock!
      refresh_capacity_projection_state!(pool, projection, @now)
      AgencyCommand::Result.new(status: :updated, record: projection.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
