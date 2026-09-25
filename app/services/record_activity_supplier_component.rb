# frozen_string_literal: true

class RecordActivitySupplierComponent < AgencyCommand
  SHAPES = {
    "fixed" => { calculation_kind: "fixed" },
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
    attributes = @attributes.to_h.with_indifferent_access
    item = @arrangement.arrangement_items.find(attributes[:arrangement_item_id])
    version = @arrangement.versions.find_by!(status: "draft")
    category = version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id).category
    RecordTypedSupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, category: category,
      shapes: SHAPES, attributes: attributes, idempotency_key: @idempotency_key
    ).call
  end
end
