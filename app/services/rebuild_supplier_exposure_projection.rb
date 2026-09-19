# frozen_string_literal: true

# Idempotent repair that rebuilds Arrangement exposure projections from sources.
# Emits no ordinary success audit.
class RebuildSupplierExposureProjection < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
  end

  def call
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!(:manage_departures)
      arrangement = lock_arrangement_for!(@arrangement)
      lock_departure_for!(arrangement.departure_id)
      rebuild_exposure_projection_already_locked!(arrangement)
      Result.new(status: :updated, record: arrangement)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
