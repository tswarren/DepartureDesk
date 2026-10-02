# frozen_string_literal: true

class RecordTransportationCoachChange < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, item:, quantity:, effective_on:, idempotency_key:,
    event_type:, evidence_attributes:, projection_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @item = item
    @quantity = quantity
    @effective_on = effective_on
    @idempotency_key = idempotency_key
    @event_type = event_type.to_s
    @evidence_attributes = evidence_attributes
    @projection_lock_version = projection_lock_version
  end

  def call
    ensure_arrangement_actor!
    unless %w[increased released].include?(@event_type)
      raise Error.new("Record an increase or a release.", code: :invalid)
    end

    version = @arrangement.governing_version || @arrangement.versions.find_by!(status: "activated")
    pool_definition = version.capacity_pool_definitions.find_by!(arrangement_item: @item)
    pool = pool_definition.capacity_pool
    quantity = Integer(@quantity)
    if @event_type == "increased"
      ceiling = pool_definition.maximum_total_resource_units
      confirmed = BillableCapacityQuantity.confirmed_for_ceiling(pool:, version:)
      if ceiling && confirmed + quantity > ceiling
        raise Error.new("That coach is beyond the agreement ceiling and stays Advanced Supplier planning.", code: :invalid)
      end
    end

    command = @event_type == "increased" ? IncreaseCapacity : ReleaseCapacity
    result = command.new(
      agency: @agency, actor: @actor, pool:, quantity:,
      projection_lock_version: @projection_lock_version,
      idempotency_key: @idempotency_key,
      effective_on: @effective_on,
      attributes: @evidence_attributes
    ).call
    RebuildSupplierExposureProjection.new(
      agency: @agency, actor: @actor, arrangement: @arrangement
    ).call
    result
  end
end
