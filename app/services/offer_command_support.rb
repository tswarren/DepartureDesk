# frozen_string_literal: true

module OfferCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  EXPLICIT_FULFILLMENT_BASES = %w[on_request agency_fulfilled externally_fulfilled].freeze
  OUTLINE_FULFILLMENT_BASES = (EXPLICIT_FULFILLMENT_BASES + %w[undecided]).freeze
  RESOLVABLE_FULFILLMENT_BASES = EXPLICIT_FULFILLMENT_BASES

  private

  def ensure_offer_actor!
    ensure_arrangement_actor!(:manage_departures)
  end

  def lock_authorized_offer_agency!
    lock_authorized_agency!(:manage_departures)
  end

  def lock_offer_for!(offer)
    @agency.service_offers.lock.find(offer.is_a?(ServiceOffer) ? offer.id : offer)
  end

  def lock_editable_offer_draft!(offer)
    offer.versions.lock.find_by(status: "draft") ||
      raise(AgencyCommand::Error.new("That service offer has no editable draft.", code: :invalid_state))
  end

  def lock_departure_offer_draft!(offer)
    departure = lock_departure_for!(offer.departure_id)
    locked_offer = lock_offer_for!(offer)
    version = lock_editable_offer_draft!(locked_offer)
    [ departure, locked_offer, version ]
  end

  def ensure_departure_accepts_new_offer!(departure)
    return if departure.draft? || departure.active?

    raise AgencyCommand::Error.new("A departed departure cannot create service offers.", code: :invalid_state) if departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_departure_accepts_source_expansion!(departure)
    return if departure.draft? || departure.active?

    raise AgencyCommand::Error.new("A departed departure cannot add service offer sources.", code: :invalid_state)
  end

  def ensure_departure_accepts_price_expansion!(departure)
    return if departure.draft? || departure.active?

    raise AgencyCommand::Error.new("A departed departure cannot change a service offer price.", code: :invalid_state)
  end

  def ensure_departure_accepts_price_removal!(departure)
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def ensure_offer_draft_editable!(departure, offer, version)
    unless version.draft? && offer.editable_draft_version&.id == version.id
      raise AgencyCommand::Error.new("That service offer cannot be edited.", code: :invalid_state)
    end
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def normalize_offer_name(value)
    name = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a name.", code: :invalid) if name.blank?
    if name.length > ServiceOffer::NAME_LIMIT
      raise AgencyCommand::Error.new("Name must be #{ServiceOffer::NAME_LIMIT} characters or fewer.", code: :invalid)
    end

    name
  end

  def normalize_client_title(value)
    title = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a client title.", code: :invalid) if title.blank?
    if title.length > ServiceOfferDefinition::TITLE_LIMIT
      raise AgencyCommand::Error.new("Client title must be #{ServiceOfferDefinition::TITLE_LIMIT} characters or fewer.", code: :invalid)
    end

    title
  end

  def normalize_client_description(value)
    description = value.to_s.strip.presence
    if description && description.length > ServiceOfferDefinition::DESCRIPTION_LIMIT
      raise AgencyCommand::Error.new(
        "Client description must be #{ServiceOfferDefinition::DESCRIPTION_LIMIT} characters or fewer.",
        code: :invalid
      )
    end

    description
  end

  def normalize_client_timing_text(value)
    text = value.to_s.strip.presence
    if text && text.length > ServiceOfferDefinition::CLIENT_TIMING_LIMIT
      raise AgencyCommand::Error.new(
        "Client timing must be #{ServiceOfferDefinition::CLIENT_TIMING_LIMIT} characters or fewer.",
        code: :invalid
      )
    end

    text
  end

  def boolean_flag(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def resolve_source_pin!(arrangement:, version:, attributes:)
    item = arrangement.arrangement_items.find_by(id: attributes[:arrangement_item_id])
    raise AgencyCommand::Error.new("That arrangement item was not found.", code: :not_found) if item.nil?

    item_definition = version.arrangement_item_definitions.find_by(arrangement_item_id: item.id)
    raise AgencyCommand::Error.new("That arrangement item is not in the selected planning version.", code: :invalid) if item_definition.nil?

    occurrence = resolve_optional_child!(
      item.service_occurrences, attributes[:service_occurrence_id], "service occurrence"
    )
    occurrence_definition = if occurrence
      version.service_occurrence_definitions.find_by(service_occurrence_id: occurrence.id) ||
        raise(AgencyCommand::Error.new("That occurrence is not in the selected planning version.", code: :invalid))
    end

    resource = resolve_optional_child!(
      item.supplier_resources, attributes[:supplier_resource_id], "supplier resource"
    )
    resource_definition = if resource
      version.supplier_resource_definitions.find_by(supplier_resource_id: resource.id) ||
        raise(AgencyCommand::Error.new("That resource is not in the selected planning version.", code: :invalid))
    end

    pool = resolve_optional_child!(item.capacity_pools, attributes[:capacity_pool_id], "capacity pool")
    pool_definition = if pool
      unless occurrence && resource
        raise AgencyCommand::Error.new("A Pool pin requires both an Occurrence and a Resource.", code: :invalid)
      end
      unless pool.service_occurrence_id == occurrence.id && pool.supplier_resource_id == resource.id
        raise AgencyCommand::Error.new("That pool is not in the bound occurrence and resource.", code: :invalid)
      end
      version.capacity_pool_definitions.find_by(capacity_pool_id: pool.id) ||
        raise(AgencyCommand::Error.new("That pool is not in the selected planning version.", code: :invalid))
    end

    {
      arrangement: arrangement,
      version: version,
      item: item,
      item_definition: item_definition,
      occurrence: occurrence,
      occurrence_definition: occurrence_definition,
      resource: resource,
      resource_definition: resource_definition,
      pool: pool,
      pool_definition: pool_definition
    }
  end

  def resolve_optional_child!(scope, id, label)
    uuid = parse_optional_uuid(id, label.to_s.humanize)
    return if uuid.blank?

    record = scope.find_by(id: uuid)
    raise AgencyCommand::Error.new("That #{label} was not found.", code: :not_found) if record.nil?

    record
  end

  def resolve_planning_version!(arrangement, requested_version_id:, use_tentative_draft:)
    unless arrangement.draft? || arrangement.active?
      raise AgencyCommand::Error.new("That supplier arrangement cannot supply a service offer.", code: :invalid_state)
    end

    draft = arrangement.versions.find_by(status: "draft")
    governing = arrangement.governing_version

    if requested_version_id.present?
      version = arrangement.versions.find_by(id: requested_version_id)
      raise AgencyCommand::Error.new("That arrangement version was not found.", code: :not_found) if version.nil?
      ensure_selectable_planning_version!(arrangement, version, governing:, draft:)
      return version
    end

    if arrangement.active?
      return draft if use_tentative_draft && draft
      return governing if governing
    end

    draft || raise(AgencyCommand::Error.new("That supplier arrangement has no selectable planning version.", code: :invalid_state))
  end

  def ensure_selectable_planning_version!(arrangement, version, governing:, draft:)
    if arrangement.active?
      return if governing && version.id == governing.id
      return if version.draft? && draft&.id == version.id

      raise AgencyCommand::Error.new(
        "Choose the governing activated version or the labeled tentative draft.",
        code: :invalid
      )
    end

    return if version.draft? && draft&.id == version.id

    raise AgencyCommand::Error.new("A never-activated arrangement can only offer its labeled draft.", code: :invalid)
  end

  def effective_provider_for(arrangement, item_definition, occurrence_definition)
    occurrence_definition&.service_provider ||
      item_definition.default_service_provider ||
      arrangement.contracting_supplier
  end

  def source_name_for(pin)
    pin[:occurrence_definition]&.name.presence || pin[:item_definition].name
  end

  def source_description_for(pin)
    pin[:occurrence_definition]&.description.presence || pin[:item_definition].description
  end

  def binding_attributes_from_pin(pin, membership:, position:, group_key: nil, group_label: nil, dependencies: {})
    {
      agency: @agency,
      departure_id: pin[:arrangement].departure_id,
      supplier_arrangement: pin[:arrangement],
      arrangement_item: pin[:item],
      service_occurrence: pin[:occurrence],
      supplier_resource: pin[:resource],
      capacity_pool: pin[:pool],
      supplier_arrangement_version: pin[:version],
      arrangement_item_definition: pin[:item_definition],
      service_occurrence_definition: pin[:occurrence_definition],
      supplier_resource_definition: pin[:resource_definition],
      capacity_pool_definition: pin[:pool_definition],
      membership_kind: membership,
      alternative_group_key: group_key,
      alternative_group_label: group_label,
      position: position,
      depend_on_item_name: boolean_flag(dependencies[:depend_on_item_name]),
      depend_on_item_description: boolean_flag(dependencies[:depend_on_item_description]),
      depend_on_occurrence_name: boolean_flag(dependencies[:depend_on_occurrence_name]),
      depend_on_occurrence_description: boolean_flag(dependencies[:depend_on_occurrence_description]),
      depend_on_resource_name: boolean_flag(dependencies[:depend_on_resource_name]),
      depend_on_resource_description: boolean_flag(dependencies[:depend_on_resource_description]),
      depend_on_pool_label: boolean_flag(dependencies[:depend_on_pool_label]),
      depend_on_pool_unit_label: boolean_flag(dependencies[:depend_on_pool_unit_label]),
      client_title_provenance: dependencies[:client_title_provenance].presence || "source_name",
      client_description_provenance: dependencies[:client_description_provenance].presence || "none"
    }
  end
end
