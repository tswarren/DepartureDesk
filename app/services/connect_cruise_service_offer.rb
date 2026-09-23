# frozen_string_literal: true

class ConnectCruiseServiceOffer < AgencyCommand
  include OfferCommandSupport
  include CruiseServiceConnectionGraph

  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
    @mode = @attributes[:mode].to_s
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Choose how to connect this cruise.", code: :invalid) unless %w[new existing later].include?(@mode)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      lock_agency_user!(@actor)
      arrangement = @agency.supplier_arrangements.find(@arrangement.id)
      ancestry_version = ancestry_version_for(arrangement)
      shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: arrangement, version: ancestry_version).call
      raise Error.new("Open advanced Supplier planning for this Arrangement.", code: :invalid) unless shape.compatible?

      item = shape.item
      raise Error.new("That cruise item was not found.", code: :not_found) if @attributes[:arrangement_item_id].present? && @attributes[:arrangement_item_id] != item.id

      lock_suppliers_in_uuid_order!(
        arrangement.contracting_supplier_id,
        shape.item_definition&.default_service_provider_id,
        shape.occurrence_definition&.service_provider_id
      )
      departure = lock_departure_for!(arrangement.departure_id)
      arrangement = lock_arrangement_for!(arrangement)
      ancestry_version = arrangement.versions.lock.find(ancestry_version.id)
      lock_selected_definitions!(ancestry_version, shape)
      shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: arrangement, version: ancestry_version).call

      title = normalize_client_title(@attributes[:title].presence || @attributes[:client_title])
      description = normalize_client_description(@attributes[:description].presence || @attributes[:client_description])
      resource_ids = Array(@attributes[:supplier_resource_ids]).map(&:to_s).reject(&:blank?)
      lock_category_definitions!(ancestry_version, resource_ids) unless @mode == "later"
      payload = idempotency_payload(departure, arrangement, shape.item, title, description, resource_ids, ancestry_version)

      result = idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        result_class: ServiceOffer
      ) do
        write_connection!(departure, arrangement, ancestry_version, shape, title, description, resource_ids)
      rescue ActiveRecord::RecordNotUnique
        raise Error.new("This cruise already has a Client service.", code: :conflict)
      end

      status = result.status == :created ? public_status : result.status
      Result.new(status: status, record: result.record)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ancestry_version_for(arrangement)
    requested = @attributes[:supplier_arrangement_version_id].presence
    tentative = boolean_flag(@attributes[:use_tentative_draft])
    version = resolve_planning_version!(arrangement, requested_version_id: requested, use_tentative_draft: tentative)
    if version.draft? && !tentative
      raise Error.new("Choose the activated cruise version, or mark this connection as tentative.", code: :invalid)
    end
    if tentative && !version.draft?
      raise Error.new("A tentative connection uses the draft cruise version.", code: :invalid)
    end

    version
  end

  def idempotency_payload(departure, arrangement, item, title, description, resource_ids, ancestry_version)
    {
      departure_id: departure.id,
      supplier_arrangement_id: arrangement.id,
      supplier_arrangement_version_id: ancestry_version.id,
      arrangement_item_id: item.id,
      mode: @mode,
      service_offer_id: @mode == "existing" ? @attributes[:service_offer_id].to_s : nil,
      use_tentative_draft: boolean_flag(@attributes[:use_tentative_draft]),
      title: title,
      description: description,
      supplier_resource_ids: @mode == "later" ? [] : resource_ids
    }
  end

  def write_connection!(departure, arrangement, arrangement_version, shape, title, description, resource_ids)
    if @mode == "later"
      ensure_current_lock_version!(arrangement_version, @attributes[:arrangement_lock_version])
      ensure_departure_accepts_new_offer!(departure)
      CruiseServiceConnectionSupport.assert_item_available!(shape.item)
      offer = create_outline!(departure, arrangement, shape.item, title, description, "undecided")
      version = offer.editable_draft_version
      audit_connection!(offer, version, arrangement, nil, shape.item, "outlined")
      return offer
    end

    ensure_current_lock_version!(arrangement_version, @attributes[:arrangement_lock_version])
    pins = category_pins_for!(shape, arrangement_version, resource_ids)
    if @mode == "new"
      ensure_departure_accepts_new_offer!(departure)
      CruiseServiceConnectionSupport.assert_item_available!(shape.item)
      offer = create_outline!(departure, arrangement, shape.item, title, description, "m3_backed")
      version = offer.editable_draft_version
    else
      offer = lock_offer_for!(@agency.service_offers.find(@attributes[:service_offer_id]))
      version = lock_editable_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, version)
      ensure_current_lock_version!(version, @attributes[:version_lock_version])
      ensure_existing_outline!(offer, version, shape.item)
      CruiseServiceConnectionSupport.assert_item_available!(shape.item, except_offer: offer)
      claim_item!(offer, shape.item, arrangement)
      version.definition.update!(
        client_title: title,
        client_description: description,
        fulfillment_basis: "m3_backed"
      )
    end

    group = create_choice_group!(offer, version, departure)
    pins.each_with_index do |pin, index|
      create_cabin_choice!(offer: offer, version: version, departure: departure, group: group, pin: pin, position: index + 1)
    end
    bump_version!(version)
    audit_connection!(offer, version, arrangement, arrangement_version, shape.item, public_status)
    offer
  end

  def create_outline!(departure, arrangement, item, title, description, fulfillment)
    offer = @agency.service_offers.create!(
      departure: departure,
      name: title,
      intended_arrangement_item: item,
      intended_supplier_arrangement: arrangement
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
      client_title: title,
      client_description: description,
      fulfillment_basis: fulfillment
    )
    offer
  end

  def ensure_existing_outline!(offer, version, item)
    definition = version.definition
    unless offer.departure_id == @arrangement.departure_id && version.draft? && definition&.undecided?
      raise Error.new("Choose an undecided service outline on this departure.", code: :invalid)
    end
    if version.owning_package_version_id.present? || version.source_bindings.any? || version.choice_groups.any? || version.choice_options.any?
      raise Error.new("Choose an undecided service outline on this departure.", code: :invalid)
    end
    if offer.intended_arrangement_item_id.present? && offer.intended_arrangement_item_id != item.id
      raise Error.new("That service is already connected to a different cruise.", code: :conflict)
    end
  end

  def lock_selected_definitions!(version, shape)
    version.arrangement_item_definitions.lock.find(shape.item_definition.id)
    version.service_occurrence_definitions.lock.find(shape.occurrence_definition.id) if shape.occurrence_definition
  end

  def lock_category_definitions!(version, resource_ids)
    return if resource_ids.empty?

    version.supplier_resource_definitions.where(supplier_resource_id: resource_ids).order(:id).lock.load
    version.capacity_pool_definitions.where(supplier_resource_id: resource_ids).order(:id).lock.load
  end

  def public_status
    { "new" => :created, "existing" => :connected, "later" => :outlined }.fetch(@mode)
  end
end
