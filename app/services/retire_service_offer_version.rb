# frozen_string_literal: true

class RetireServiceOfferVersion < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, reason:)
    @agency = agency
    @actor = actor
    @offer = offer
    @reason = reason.to_s.strip
  end

  def call
    ensure_offer_actor!
    raise Error.new("Enter a retirement reason.", code: :invalid) if @reason.blank?

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      offer = lock_offer_for!(@offer)
      version = offer.current_published_version
      raise Error.new("That service offer has no published version.", code: :invalid_state) if version.nil?
      version = offer.versions.lock.find(version.id)
      raise Error.new("That service offer version is not published.", code: :invalid_state) unless version.published?

      version.update!(status: "retired", retired_at: Time.current)
      state = version.sales_state
      state.update!(sales_enabled: false) if state&.sales_enabled
      offer.update!(current_published_version: nil) if offer.current_published_version_id == version.id
      audit!(
        agency: @agency, action: "service_offer.retired", subject: offer, actor: @actor,
        details: {
          "service_offer_id" => offer.id,
          "service_offer_version_id" => version.id,
          "reason" => @reason
        }
      )
      offer
    end
  end
end
