# frozen_string_literal: true

class CreateTransportationSegment < AgencyCommand
  include TypedItemWrite

  def initialize(agency:, actor:, departure:, arrangement_attributes:, item_attributes:, occurrence_attributes:, idempotency_key:, arrangement: nil, version_lock_version: nil, seat_count: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @arrangement_attributes = arrangement_attributes
    @item_attributes = item_attributes
    @occurrence_attributes = occurrence_attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
    @version_lock_version = version_lock_version
    @seat_count = seat_count
  end

  def call
    pickup = @occurrence_attributes.delete(:pickup)
    dropoff = @occurrence_attributes.delete(:dropoff)
    lines = []
    lines << "Pickup: #{pickup}" if pickup.present?
    lines << "Drop-off: #{dropoff}" if dropoff.present?
    @occurrence_attributes[:description] = lines.join("\n").presence
    resource = @seat_count.present? ? { name: "Vehicle", maximum_occupancy: @seat_count } : nil
    establish_typed_item!(
      departure: @departure, arrangement: @arrangement, category: "ground_transportation",
      capacity_management: "unmanaged", arrangement_attributes: @arrangement_attributes,
      item_attributes: @item_attributes, occurrence_attributes: @occurrence_attributes,
      idempotency_key: @idempotency_key, version_lock_version: @version_lock_version,
      resource_attributes: resource
    )
  end
end
