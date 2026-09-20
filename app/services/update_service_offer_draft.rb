# frozen_string_literal: true

class UpdateServiceOfferDraft < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, offer:, attributes:, offer_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @offer = offer
    @attributes = attributes.to_h.with_indifferent_access
    @offer_lock_version = offer_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_offer_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_offer_agency!
      departure, offer, version = if boolean_flag(@attributes[:refresh_bindings])
        lock_offer_update_with_sources!
      else
        lock_departure_offer_draft!(@offer)
      end
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(offer, @offer_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)

      definition = version.definition
      raise Error.new("That service offer has no draft definition.", code: :invalid_state) if definition.nil?

      name = @attributes.key?(:name) ? normalize_offer_name(@attributes[:name]) : offer.name
      client_title = @attributes.key?(:client_title) ? normalize_client_title(@attributes[:client_title]) : definition.client_title
      client_description = if @attributes.key?(:client_description)
        normalize_client_description(@attributes[:client_description])
      else
        definition.client_description
      end

      offer.update!(name: name) if name != offer.name
      definition.update!(client_title:, client_description:)

      if boolean_flag(@attributes[:refresh_bindings])
        refresh_bindings!(version, definition)
      end

      audit!(
        agency: @agency,
        action: "service_offer.updated",
        subject: offer,
        actor: @actor,
        details: {
          "service_offer_id" => offer.id,
          "service_offer_version_id" => version.id
        }
      )
      Result.new(status: :updated, record: offer.reload)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def lock_offer_update_with_sources!
    offer = @agency.service_offers.find(@offer.id)
    draft = offer.editable_draft_version
    bindings = draft ? draft.source_bindings.includes(
      :supplier_arrangement, :arrangement_item_definition, :service_occurrence_definition
    ) : []
    supplier_ids = bindings.flat_map { |binding|
      arrangement = binding.supplier_arrangement
      provider = effective_provider_for(
        arrangement,
        binding.arrangement_item_definition,
        binding.service_occurrence_definition
      )
      [ arrangement.contracting_supplier_id, provider.id ]
    }
    lock_suppliers_in_uuid_order!(*supplier_ids)
    departure = lock_departure_for!(offer.departure_id)
    bindings.map(&:supplier_arrangement_id).uniq.sort.each do |arrangement_id|
      arrangement = lock_arrangement_for!(arrangement_id)
      version_ids = bindings.select { |row| row.supplier_arrangement_id == arrangement_id }
        .map(&:supplier_arrangement_version_id).uniq
      arrangement.versions.lock.where(id: version_ids).load
    end
    locked_offer = lock_offer_for!(offer)
    version = lock_editable_offer_draft!(locked_offer)
    [ departure, locked_offer, version ]
  end

  def refresh_bindings!(version, definition)
    version.source_bindings.order(:position).each do |binding|
      arrangement = @agency.supplier_arrangements.find(binding.supplier_arrangement_id)
      planning_version = arrangement.versions.find(binding.supplier_arrangement_version_id)
      pin = resolve_source_pin!(
        arrangement: arrangement,
        version: planning_version,
        attributes: {
          arrangement_item_id: binding.arrangement_item_id,
          service_occurrence_id: binding.service_occurrence_id,
          supplier_resource_id: binding.supplier_resource_id,
          capacity_pool_id: binding.capacity_pool_id
        }
      )
      binding.update!(
        arrangement_item_definition: pin[:item_definition],
        service_occurrence_definition: pin[:occurrence_definition],
        supplier_resource_definition: pin[:resource_definition],
        capacity_pool_definition: pin[:pool_definition],
        client_title_provenance: "staff_entered",
        client_description_provenance: definition.client_description.present? ? "staff_entered" : "none"
      )
    end
  end
end
