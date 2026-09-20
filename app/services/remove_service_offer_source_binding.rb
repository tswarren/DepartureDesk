# frozen_string_literal: true

class RemoveServiceOfferSourceBinding < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, binding:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @binding = binding
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      _departure, offer, version = lock_departure_offer_draft!(@offer)
      ensure_offer_draft_editable!(_departure, offer, version)
      ensure_current_lock_version!(version, @version_lock_version)
      binding = version.source_bindings.lock.find_by(id: @binding.id)
      raise Error.new("That source binding was not found.", code: :not_found) if binding.nil?

      if version.definition&.m3_backed? && version.source_bindings.where(membership_kind: "required").count <= 1 && binding.required?
        raise Error.new("An M3-backed service offer must keep at least one required source.", code: :invalid)
      end

      binding_id = binding.id
      binding.destroy!
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "service_offer.source_binding_removed",
        subject: offer,
        actor: @actor,
        details: {
          "service_offer_id" => offer.id,
          "service_offer_version_id" => version.id,
          "service_offer_source_binding_id" => binding_id
        }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
