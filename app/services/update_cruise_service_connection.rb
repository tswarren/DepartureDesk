# frozen_string_literal: true

class UpdateCruiseServiceConnection < AgencyCommand
  include OfferCommandSupport
  include CruiseServiceConnectionGraph

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
      version = offer.editable_draft_version
      raise Error.new("That service offer cannot be edited.", code: :invalid_state) if version.nil?

      connection = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: offer, version: version).call
      raise Error.new("Open advanced Service Offer editing for this service.", code: :invalid) unless connection.compatible?

      arrangement = connection.arrangement
      arrangement_version = connection.arrangement_version
      lock_suppliers_in_uuid_order!(
        arrangement.contracting_supplier_id,
        connection.item && arrangement.versions.find(arrangement_version.id)
          .arrangement_item_definitions.find_by(arrangement_item_id: connection.item.id)
          &.default_service_provider_id,
        arrangement_version.service_occurrence_definitions.find_by(service_occurrence_id: connection.occurrence.id)
          &.service_provider_id
      )
      departure = lock_departure_for!(offer.departure_id)
      arrangement = lock_arrangement_for!(arrangement)
      arrangement_version = arrangement.versions.lock.find(arrangement_version.id)
      offer = lock_offer_for!(offer)
      version = lock_editable_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, version)

      title = normalize_client_title(@attributes[:title].presence || @attributes[:client_title])
      description = normalize_client_description(@attributes[:description].presence || @attributes[:client_description])
      resource_ids = Array(@attributes[:supplier_resource_ids]).map(&:to_s).reject(&:blank?)
      payload = {
        service_offer_id: offer.id,
        service_offer_version_id: version.id,
        supplier_arrangement_version_id: arrangement_version.id,
        title: title,
        description: description,
        supplier_resource_ids: resource_ids
      }

      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOffer
      ) do
        ensure_current_lock_version!(version, @attributes[:version_lock_version])
        ensure_current_lock_version!(arrangement_version, @attributes[:arrangement_lock_version])
        connection = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: offer, version: version).call
        raise Error.new("Open advanced Service Offer editing for this service.", code: :invalid) unless connection.compatible?
        raise Error.new("This connection is pinned to a different sailing version.", code: :conflict) if connection.arrangement_version.id != arrangement_version.id

        ensure_same_version_categories!(arrangement_version, resource_ids)
        CruiseServiceConnectionSupport.assert_item_available!(connection.item, except_offer: offer)
        claim_item!(offer, connection.item, arrangement) if offer.intended_arrangement_item_id.blank?
        apply_replacement!(offer, version, departure, arrangement_version, connection, title, description, resource_ids)
        offer
      rescue ActiveRecord::RecordNotUnique
        raise Error.new("This cruise already has a Client service.", code: :conflict)
      end

      status = result.status == :created ? :updated : result.status
      Result.new(status: status, record: result.record)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def apply_replacement!(offer, version, departure, arrangement_version, connection, title, description, resource_ids)
    version.definition.update!(client_title: title, client_description: description)
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: connection.arrangement, version: arrangement_version).call
    pins = category_pins_for!(shape, arrangement_version, resource_ids)
    pins_by_resource = pins.index_by { |pin| pin[:resource].id.to_s }
    current = connection.choices.index_by { |choice| choice[:binding].supplier_resource_id.to_s }

    removed = current.except(*pins_by_resource.keys).values
    refuse_priced_removals!(version, removed.map { |choice| choice[:option] })

    retained_ids = pins_by_resource.keys & current.keys
    added_pins = pins.reject { |pin| current.key?(pin[:resource].id.to_s) }
    final_positions = {}
    pins.each_with_index do |pin, index|
      resource_id = pin[:resource].id.to_s
      choice = current[resource_id]
      final_positions[resource_id] = { position: index + 1, choice: choice }
    end

    option_finals = {}
    binding_finals = {}
    retained_ids.each do |resource_id|
      choice = current[resource_id]
      option_finals[choice[:option].id] = final_positions[resource_id][:position]
      binding_finals[choice[:binding].id] = final_positions[resource_id][:position]
    end

    existing_option_max = version.choice_options.maximum(:position)
    existing_binding_max = version.source_bindings.maximum(:position)
    destroy_choices!(removed)

    retained_options = retained_ids.map { |resource_id| current[resource_id][:option] }
    retained_bindings = retained_ids.map { |resource_id| current[resource_id][:binding] }
    replace_positions!(retained_options, option_finals, existing_max: existing_option_max, added_count: added_pins.size)
    replace_positions!(retained_bindings, binding_finals, existing_max: existing_binding_max, added_count: added_pins.size)

    group = version.choice_groups.find_by!(name: CruiseServiceConnectionSupport::GROUP_NAME)
    added_pins.each do |pin|
      create_cabin_choice!(
        offer: offer,
        version: version,
        departure: departure,
        group: group,
        pin: pin,
        position: final_positions[pin[:resource].id.to_s][:position]
      )
    end
    bump_version!(version)
    audit_connection!(offer, version, connection.arrangement, arrangement_version, connection.item, "updated")
  end

  def destroy_choices!(choices)
    choices.each do |choice|
      option = choice[:option]
      option.source_activation&.destroy!
      option.association(:source_activation).reset
      option.destroy!
      choice[:binding].destroy!
    end
  end
end
