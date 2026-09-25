# frozen_string_literal: true

class ConnectActivityServiceOffer < AgencyCommand
  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    item = arrangement.arrangement_items.find(@attributes[:arrangement_item_id])
    ConnectTypedItemService.new(
      agency: @agency, actor: @actor, arrangement: arrangement, item: item,
      attributes: @attributes, idempotency_key: @idempotency_key
    ).call
  end
end
