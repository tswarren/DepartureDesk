# frozen_string_literal: true

class DiscardServiceOfferDraft < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, reason:, offer_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @reason = reason
    @offer_lock_version = offer_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      _departure, offer, version = lock_departure_offer_draft!(@offer)
      if version.abandoned?
        return Result.new(status: :noop, record: offer)
      end

      ensure_current_lock_version!(offer, @offer_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      reason = normalize_reason(@reason)
      version.update!(status: "abandoned", abandoned_at: Time.current, abandoned_reason: reason)
      audit!(
        agency: @agency,
        action: "service_offer.discarded",
        subject: offer,
        actor: @actor,
        details: {
          "service_offer_id" => offer.id,
          "service_offer_version_id" => version.id,
          "reason" => reason
        }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
