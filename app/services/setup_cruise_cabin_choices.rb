# frozen_string_literal: true

class SetupCruiseCabinChoices < AgencyCommand
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
      raise Error.new("Enter at least one cabin category.", code: :invalid)
    end

    offer = @agency.service_offers.find(@offer.id)
    version = offer.editable_draft_version
    if offer.intended_arrangement_item_id.present? || obvious_cruise_choices?(version)
      raise Error.new(
        "This service is connected to a cruise. Edit it from the Cruise service connection workspace.",
        code: :invalid
      )
    end

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
            options: @option_names.map { |name|
              { name: name, price_effect_minor_units: 0, activation: { activation_kind: "none" } }
            }
          }
        ]
      }
    ).call
  end

  private

  def obvious_cruise_choices?(version)
    return false if version.nil?

    version.choice_groups.where(name: CruiseServiceConnectionSupport::GROUP_NAME).exists? &&
      version.source_bindings.choice_gated.exists?
  end
end
