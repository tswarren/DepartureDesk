# frozen_string_literal: true

class AddServiceOfferSourceBinding < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, attributes:, version_lock_version:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      arrangement = @agency.supplier_arrangements.find_by(id: @attributes[:supplier_arrangement_id])
      raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.nil?

      planning_version = resolve_planning_version!(
        arrangement,
        requested_version_id: @attributes[:supplier_arrangement_version_id],
        use_tentative_draft: boolean_flag(@attributes[:use_tentative_draft])
      )
      item_definition = planning_version.arrangement_item_definitions.find_by(
        arrangement_item_id: @attributes[:arrangement_item_id]
      )
      occurrence_definition = if @attributes[:service_occurrence_id].present?
        planning_version.service_occurrence_definitions.find_by(
          service_occurrence_id: @attributes[:service_occurrence_id]
        )
      end
      provider = effective_provider_for(arrangement, item_definition, occurrence_definition) if item_definition
      lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id, provider&.id)
      departure = lock_departure_for!(@offer.departure_id)
      raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.departure_id != departure.id
      arrangement = lock_arrangement_for!(arrangement)
      planning_version = arrangement.versions.lock.find(planning_version.id)
      offer = lock_offer_for!(@offer)
      version = lock_editable_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(version, @version_lock_version)
      definition = version.definition
      unless definition&.m3_backed?
        raise Error.new("Bindings can only be added to an M3-backed service offer.", code: :invalid)
      end
      pin = resolve_source_pin!(arrangement:, version: planning_version, attributes: @attributes)
      membership = @attributes[:membership_kind].presence || "required"
      unless ServiceOfferSourceBinding::MEMBERSHIP_KINDS.include?(membership)
        raise Error.new("Choose required or alternative membership.", code: :invalid)
      end

      payload = {
        service_offer_id: offer.id,
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: planning_version.id,
        arrangement_item_id: pin[:item].id,
        service_occurrence_id: pin[:occurrence]&.id,
        supplier_resource_id: pin[:resource]&.id,
        capacity_pool_id: pin[:pool]&.id,
        membership_kind: membership,
        alternative_group_key: @attributes[:alternative_group_key],
        alternative_group_label: @attributes[:alternative_group_label]
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOfferSourceBinding
      ) do
        position = version.source_bindings.maximum(:position).to_i + 1
        binding = version.source_bindings.create!(
          binding_attributes_from_pin(
            pin,
            membership: membership,
            position: position,
            group_key: @attributes[:alternative_group_key],
            group_label: @attributes[:alternative_group_label],
            dependencies: @attributes
          ).merge(service_offer: offer)
        )
        bump_version!(version)
        audit!(
          agency: @agency,
          action: "service_offer.source_binding_added",
          subject: offer,
          actor: @actor,
          details: {
            "service_offer_id" => offer.id,
            "service_offer_version_id" => version.id,
            "service_offer_source_binding_id" => binding.id,
            "arrangement_item_id" => pin[:item].id
          }
        )
        binding
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
