# frozen_string_literal: true

class RecordHotelMilestone < AgencyCommand
  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes
    @idempotency_key = idempotency_key
  end

  def call
    RecordTypedMilestone.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, category: "lodging",
      attributes: @attributes, idempotency_key: @idempotency_key
    ).call
  end
end
