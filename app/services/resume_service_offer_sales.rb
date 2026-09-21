# frozen_string_literal: true

class ResumeServiceOfferSales < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:)
    @agency = agency
    @actor = actor
    @offer = offer
  end

  def call
    ensure_offer_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      offer = lock_offer_for!(@offer)
      version = offer.current_published_version
      raise Error.new("That service offer has no published version.", code: :invalid_state) if version.nil?
      version = offer.versions.lock.find(version.id)
      raise Error.new("That service offer version is not published.", code: :invalid_state) unless version.published?
      raise Error.new("That service offer is not structurally eligible to resume sales.", code: :invalid_state) if version.departure.departed?

      state = ServiceOfferVersionSalesState.lock.find(version.sales_state.id)
      return offer if state.sales_enabled

      state.update!(sales_enabled: true)
      audit!(
        agency: @agency, action: "service_offer.sales_resumed", subject: offer, actor: @actor,
        details: { "service_offer_id" => offer.id, "service_offer_version_id" => version.id }
      )
      offer
    end
  end
end
