# frozen_string_literal: true

class RemoveCruiseClientTermSchedule < AgencyCommand
  include CruiseClientTermWrite

  def initialize(agency:, actor:, offer:, attributes:)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    ensure_offer_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      lock_agency_user!(@actor)
      offer = @agency.service_offers.find(@offer.id)
      departure, offer, version = lock_departure_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(version, @attributes[:version_lock_version])
      _shape, option, _binding, _resource = load_context!(offer)
      ensure_typed_graph!(version)
      remove_category!(version, option)
      bump_version!(version)
      audit_terms!(offer, version, option, "removed", 0, 0)
      AgencyCommand::Result.new(status: :removed, record: version.reload.price_definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
