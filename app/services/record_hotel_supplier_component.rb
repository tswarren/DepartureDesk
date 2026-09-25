# frozen_string_literal: true

class RecordHotelSupplierComponent < AgencyCommand
  SHAPES = {
    "fixed" => { calculation_kind: "fixed" },
    "per_room" => { calculation_kind: "unit_rate", quantity_basis: "resource_units" },
    "per_room_night" => { calculation_kind: "unit_rate", quantity_basis: "resource_nights" },
    "per_person" => { calculation_kind: "unit_rate", quantity_basis: "persons" },
    "per_person_night" => { calculation_kind: "unit_rate", quantity_basis: "person_nights" },
    "percentage" => { calculation_kind: "percentage" }
  }.freeze

  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes
    @idempotency_key = idempotency_key
  end

  def call
    RecordTypedSupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, category: "lodging",
      shapes: SHAPES, attributes: @attributes, idempotency_key: @idempotency_key
    ).call
  end
end
