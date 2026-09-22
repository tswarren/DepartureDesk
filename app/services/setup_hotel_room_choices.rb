# frozen_string_literal: true

class SetupHotelRoomChoices < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, version_lock_version:, option_names:)
    @agency = agency
    @actor = actor
    @offer = offer
    @version_lock_version = version_lock_version
    @option_names = Array(option_names).map { |name| name.to_s.strip }.reject(&:blank?)
  end

  def call
    if @option_names.empty?
      raise Error.new("Enter at least one room category.", code: :invalid)
    end

    UpdateServiceOfferChoices.new(
      agency: @agency,
      actor: @actor,
      offer: @offer,
      version_lock_version: @version_lock_version,
      attributes: {
        groups: [
          {
            name: "Room category",
            min_selections: 1,
            max_selections: 1,
            options: @option_names.map { |name|
              { name: name, price_effect_minor_units: 0, activation: { activation_kind: "none" } }
            }
          }
        ]
      }
    ).call
  end
end
