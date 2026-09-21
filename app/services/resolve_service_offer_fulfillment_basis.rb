# frozen_string_literal: true

class ResolveServiceOfferFulfillmentBasis < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, fulfillment_basis:, version_lock_version:, offer_lock_version: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @fulfillment_basis = fulfillment_basis.to_s
    @version_lock_version = version_lock_version
    @offer_lock_version = offer_lock_version
  end

  def call
    ensure_offer_actor!
    unless RESOLVABLE_FULFILLMENT_BASES.include?(@fulfillment_basis)
      raise Error.new("Choose on request, Agency fulfilled, or externally fulfilled.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_current_lock_version!(offer, @offer_lock_version) if @offer_lock_version.present?

      definition = version.definition
      raise Error.new("That service offer has no draft definition.", code: :invalid_state) if definition.nil?
      unless definition.undecided?
        raise Error.new("Only an undecided draft can resolve fulfillment this way.", code: :invalid_state)
      end
      if version.source_bindings.exists?
        raise Error.new("Remove source bindings before choosing a non-Supplier fulfillment.", code: :invalid)
      end

      from_basis = definition.fulfillment_basis
      definition.update!(fulfillment_basis: @fulfillment_basis)
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "service_offer.fulfillment_basis_resolved",
        subject: offer,
        actor: @actor,
        details: {
          "service_offer_id" => offer.id,
          "service_offer_version_id" => version.id,
          "from_fulfillment_basis" => from_basis,
          "to_fulfillment_basis" => @fulfillment_basis
        }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
