# frozen_string_literal: true

class PauseServiceOfferSales < AgencyCommand
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

      state = ServiceOfferVersionSalesState.lock.find(version.sales_state.id)
      return offer unless state.sales_enabled

      state.update!(sales_enabled: false)
      audit!(
        agency: @agency, action: "service_offer.sales_paused", subject: offer, actor: @actor,
        details: { "service_offer_id" => offer.id, "service_offer_version_id" => version.id }
      )
      offer
    end
  end
end
