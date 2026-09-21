# frozen_string_literal: true

class SetupCruiseCabinChoices < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, version_lock_version:, option_names: nil, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @version_lock_version = version_lock_version
    @option_names = Array(option_names).presence || [ "Inside", "Ocean view", "Balcony", "Suite" ]
    @idempotency_key = idempotency_key
  end

  def call
    UpdateServiceOfferChoices.new(
      agency: @agency,
      actor: @actor,
      offer: @offer,
      version_lock_version: @version_lock_version,
      attributes: {
        groups: [
          {
            name: "Cabin category",
            min_selections: 1,
            max_selections: 1,
            options: @option_names.map { |name| { name: name, price_effect_minor_units: 0, activation: { activation_kind: "none" } } }
          }
        ]
      }
    ).call
  end
end
