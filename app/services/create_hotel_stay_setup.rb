# frozen_string_literal: true

class CreateHotelStaySetup < AgencyCommand
  include TypedItemWrite

  def initialize(agency:, actor:, departure:, arrangement_attributes:, item_attributes:, occurrence_attributes:, idempotency_key:, arrangement: nil, version_lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @arrangement_attributes = arrangement_attributes
    @item_attributes = item_attributes
    @occurrence_attributes = occurrence_attributes
    @idempotency_key = idempotency_key
    @version_lock_version = version_lock_version
  end

  def call
    establish_typed_item!(
      departure: @departure, arrangement: @arrangement, category: "lodging", capacity_management: "unmanaged",
      arrangement_attributes: @arrangement_attributes, item_attributes: @item_attributes,
      occurrence_attributes: @occurrence_attributes, idempotency_key: @idempotency_key,
      version_lock_version: @version_lock_version
    )
  end
end
