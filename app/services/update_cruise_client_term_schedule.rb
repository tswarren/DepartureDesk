# frozen_string_literal: true

class UpdateCruiseClientTermSchedule < AgencyCommand
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
      shape, option, binding, resource = load_context!(offer)
      ensure_typed_graph!(version)
      cells = normalized_cells
      lock_suppliers_in_uuid_order!(shape.arrangement.contracting_supplier_id)
      if provenance_save?(version, option, cells)
        arrangement_version = shape.arrangement.versions.lock.find(binding.supplier_arrangement_version_id)
        ensure_current_lock_version!(arrangement_version, @attributes[:arrangement_lock_version])
      end
      definition = apply_cells!(departure, offer, version, option, binding, resource, cells)
      bump_version!(version)
      audit_terms!(offer, version, option, "updated", definition.service_offer_price_components.where(client_rate_category_key: option.client_rate_category_key).count, definition.service_offer_price_components.where(client_rate_category_key: option.client_rate_category_key).where.not(copied_from_supplier_cost_component_id: nil).count)
      AgencyCommand::Result.new(status: :updated, record: definition)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
