# frozen_string_literal: true

class CreateCruiseClientTermSchedule < AgencyCommand
  include CruiseClientTermWrite

  def initialize(agency:, actor:, offer:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
  end

  def call
    ensure_offer_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      lock_agency_user!(@actor)
      offer = @agency.service_offers.find(@offer.id)
      departure, offer, version = lock_departure_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, version)
      shape, option, binding, resource = load_context!(offer)
      ensure_typed_graph!(version, option)
      cells = normalized_cells
      lock_suppliers_in_uuid_order!(shape.arrangement.contracting_supplier_id)
      arrangement_version = nil
      if provenance_save?(version, option, cells)
        arrangement_version = shape.arrangement.versions.lock.find(binding.supplier_arrangement_version_id)
        ensure_current_lock_version!(arrangement_version, @attributes[:arrangement_lock_version])
      end
      payload = idempotency_payload(offer, version, option, cells, arrangement_version)
      idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key, payload: payload, result_class: ServiceOfferPriceDefinition
      ) do
        ensure_current_lock_version!(version, @attributes[:version_lock_version])
        definition = apply_cells!(departure, offer, version, option, binding, resource, cells)
        bump_version!(version)
        audit_terms!(offer, version, option, "created", definition.service_offer_price_components.where(client_rate_category_key: option.client_rate_category_key).count, copied_count(definition, option))
        definition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def copied_count(definition, option)
    definition.service_offer_price_components.where(client_rate_category_key: option.client_rate_category_key).where.not(copied_from_supplier_cost_component_id: nil).count
  end
end
