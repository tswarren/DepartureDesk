# frozen_string_literal: true

class RecordTransportationSupplierComponent < AgencyCommand
  SHAPES = {
    "fixed" => { calculation_kind: "fixed" },
    "per_segment" => { calculation_kind: "fixed" },
    "per_person" => { calculation_kind: "unit_rate", quantity_basis: "persons" }
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
      agency: @agency, actor: @actor, arrangement: @arrangement, category: "ground_transportation",
      shapes: SHAPES, attributes: @attributes, idempotency_key: @idempotency_key
    ).call
  end
end
