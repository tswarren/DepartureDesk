# frozen_string_literal: true

class CreateServiceOfferSuccessorDraft < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @offer = offer
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      offer = lock_offer_for!(@offer)
      departure = lock_departure_for!(offer.departure_id)
      predecessor = offer.current_published_version
      raise Error.new("Publish a version before creating a successor.", code: :invalid_state) if predecessor.nil?
      predecessor = offer.versions.lock.find(predecessor.id)
      ensure_current_lock_version!(predecessor, @version_lock_version)
      raise Error.new("A successor draft already exists.", code: :conflict) if offer.editable_draft_version

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: { service_offer_id: offer.id, predecessor_version_id: predecessor.id },
        result_class: ServiceOfferVersion
      ) do
        successor = offer.versions.create!(
          agency: @agency, departure: departure,
          version_number: offer.versions.maximum(:version_number).to_i + 1,
          status: "draft",
          copied_from_version: predecessor,
          sales_cap_quantity: predecessor.sales_cap_quantity,
          sales_cap_basis: predecessor.sales_cap_basis
        )
        OfferVersionGraphCopy.copy_service_offer_version!(
          agency: @agency, departure: departure, offer: offer,
          from: predecessor, to: successor
        )
        audit!(
          agency: @agency, action: "service_offer.successor_created", subject: offer, actor: @actor,
          details: {
            "service_offer_id" => offer.id,
            "predecessor_version_id" => predecessor.id,
            "service_offer_version_id" => successor.id
          }
        )
        successor
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A successor draft already exists.", code: :conflict)
  end
end
