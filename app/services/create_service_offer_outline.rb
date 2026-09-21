# frozen_string_literal: true

class CreateServiceOfferOutline < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_offer!(departure)

      client_title = normalize_client_title(@attributes[:client_title].presence || @attributes[:name])
      payload = {
        name: normalize_offer_name(@attributes[:name].presence || client_title),
        client_title: client_title,
        client_description: normalize_client_description(@attributes[:client_description]),
        client_timing_text: normalize_client_timing_text(@attributes[:client_timing_text]),
        fulfillment_basis: "undecided"
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload.merge(departure_id: departure.id),
        result_class: ServiceOffer
      ) do
        offer = @agency.service_offers.create!(
          departure: departure,
          name: payload[:name]
        )
        version = offer.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft"
        )
        version.create_definition!(
          agency: @agency,
          departure: departure,
          service_offer: offer,
          client_title: payload[:client_title],
          client_description: payload[:client_description],
          client_timing_text: payload[:client_timing_text],
          fulfillment_basis: "undecided"
        )
        audit!(
          agency: @agency,
          action: "service_offer.created",
          subject: offer,
          actor: @actor,
          details: {
            "service_offer_id" => offer.id,
            "service_offer_version_id" => version.id,
            "departure_id" => departure.id,
            "fulfillment_basis" => "undecided",
            "origin" => "outline"
          }
        )
        offer
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
