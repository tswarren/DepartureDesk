# frozen_string_literal: true

class RemoveServiceOfferPriceDefinition < AgencyCommand
  include PriceCommandSupport

  def initialize(agency:, actor:, offer:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_departure_accepts_price_removal!(departure)
      ensure_current_lock_version!(version, @version_lock_version)
      definition = lock_price_definition!(version)
      raise Error.new("That service offer has no price to remove.", code: :invalid_state) if definition.nil?

      details = price_audit_details(
        offer, version, definition, component_count: definition.service_offer_price_components.size
      )
      destroy_price_graph!(definition)
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "service_offer.price_removed",
        subject: offer,
        actor: @actor,
        details: details
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
