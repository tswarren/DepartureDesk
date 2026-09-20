# frozen_string_literal: true

class CreateServiceOfferFromSource < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, departure:, attributes:, idempotency_key: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      arrangement = @agency.supplier_arrangements.find_by(id: @attributes[:supplier_arrangement_id])
      raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.nil?
      raise Error.new("That supplier arrangement was not found.", code: :not_found) if arrangement.departure_id != @departure.id

      use_tentative_draft = boolean_flag(@attributes[:use_tentative_draft])
      planning_version = resolve_planning_version!(
        arrangement,
        requested_version_id: @attributes[:supplier_arrangement_version_id],
        use_tentative_draft: use_tentative_draft
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
      departure = lock_departure_for!(@departure)
      ensure_departure_accepts_new_offer!(departure)
      arrangement = lock_arrangement_for!(arrangement)
      planning_version = arrangement.versions.lock.find(planning_version.id)
      pin = resolve_source_pin!(arrangement:, version: planning_version, attributes: @attributes)
      source_name = source_name_for(pin)
      client_title = @attributes[:client_title].presence || source_name
      client_description = @attributes.key?(:client_description) ? @attributes[:client_description] : source_description_for(pin)
      display_name = @attributes[:name].presence || client_title
      title_provenance = @attributes[:client_title].present? ? "staff_entered" : "source_name"
      description_provenance =
        if @attributes.key?(:client_description)
          @attributes[:client_description].present? ? "staff_entered" : "none"
        elsif source_description_for(pin).present?
          "source_description"
        else
          "none"
        end

      payload = {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: planning_version.id,
        arrangement_item_id: pin[:item].id,
        service_occurrence_id: pin[:occurrence]&.id,
        supplier_resource_id: pin[:resource]&.id,
        capacity_pool_id: pin[:pool]&.id,
        name: normalize_offer_name(display_name),
        client_title: normalize_client_title(client_title),
        client_description: normalize_client_description(client_description),
        use_tentative_draft: use_tentative_draft,
        client_title_provenance: title_provenance,
        client_description_provenance: description_provenance
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOffer
      ) do
        offer = @agency.service_offers.create!(
          departure: departure,
          name: payload[:name]
        )
        version = offer.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: 1,
          status: "draft"
        )
        version.create_definition!(
          agency: @agency,
          departure: departure,
          service_offer: offer,
          client_title: payload[:client_title],
          client_description: payload[:client_description],
          fulfillment_basis: "m3_backed"
        )
        version.source_bindings.create!(
          binding_attributes_from_pin(
            pin,
            membership: "required",
            position: 1,
            dependencies: payload.slice(:client_title_provenance, :client_description_provenance)
          ).merge(service_offer: offer)
        )
        audit!(
          agency: @agency,
          action: "service_offer.created",
          subject: offer,
          actor: @actor,
          details: {
            "service_offer_id" => offer.id,
            "service_offer_version_id" => version.id,
            "departure_id" => departure.id,
            "fulfillment_basis" => "m3_backed",
            "supplier_arrangement_id" => arrangement.id,
            "supplier_arrangement_version_id" => planning_version.id,
            "arrangement_item_id" => pin[:item].id
          }
        )
        offer
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
