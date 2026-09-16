class RefreshCapacityProjectionJob < ApplicationJob
  queue_as :capacity

  retry_on ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure, ActiveRecord::LockWaitTimeout,
    attempts: 5, wait: :polynomially_longer

  def perform(agency_id:, capacity_pool_id:)
    agency = Agency.find_by(id: agency_id)
    return if agency.nil? || !agency.active?

    pool = agency.capacity_pools.find_by(id: capacity_pool_id)
    return if pool.nil?

    RefreshDueCapacityProjection.new(agency:, pool:).call
  rescue AgencyCommand::Error => error
    if %i[invalid unauthorized].include?(error.code)
      Rails.logger.error({
        event: "refresh_capacity_projection_job.unexpected_command_error",
        agency_id:,
        capacity_pool_id:,
        job_id:,
        error_code: error.code
      }.to_json)
    end
    raise unless %i[invalid invalid_state unauthorized conflict].include?(error.code)
  end
end
