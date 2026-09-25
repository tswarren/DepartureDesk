# frozen_string_literal: true

class ConnectTypedItemService < AgencyCommand
  include OfferCommandSupport

  def initialize(agency:, actor:, arrangement:, item:, attributes:, idempotency_key:, choice_group_name: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @item = item
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key
    @choice_group_name = choice_group_name
    @mode = @attributes[:mode].to_s
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Choose how to connect this service.", code: :invalid) unless %w[new existing later].include?(@mode)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.find_by(status: "draft")
      unless version
        raise Error.new("Open a successor draft before connecting this service.", code: :invalid_state)
      end
      requested = @attributes[:supplier_arrangement_version_id].presence
      if requested.present? && requested != version.id
        raise Error.new("Connect the current draft version.", code: :invalid)
      end
      item = arrangement.arrangement_items.find(@item.id)
      item_definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id)
      occurrence = item.service_occurrences.order(:created_at).first
      occurrence_definition = occurrence && version.service_occurrence_definitions.find_by!(service_occurrence_id: occurrence.id)
      departure = lock_departure_for!(arrangement.departure_id)
      title = normalize_client_title(@attributes[:title].presence || item_definition.name)
      description = normalize_client_description(@attributes[:description])
      resource_ids = Array(@attributes[:supplier_resource_ids]).map(&:to_s).reject(&:blank?)
      payload = {
        departure_id: departure.id, supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id, arrangement_item_id: item.id,
        mode: @mode, title: title, description: description, supplier_resource_ids: resource_ids,
        service_offer_id: @mode == "existing" ? @attributes[:service_offer_id].to_s : nil
      }
      result = idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key, payload: payload,
        result_class: ServiceOffer
      ) do
        ensure_current_lock_version!(version, @attributes[:arrangement_lock_version])
        write_connection!(departure, arrangement, version, item, item_definition, occurrence, occurrence_definition, title, description, resource_ids)
      end
      AgencyCommand::Result.new(status: result.status == :created ? public_status : result.status, record: result.record)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def write_connection!(departure, arrangement, version, item, item_definition, occurrence, occurrence_definition, title, description, resource_ids)
    if @mode == "later"
      ensure_departure_accepts_new_offer!(departure)
      TypedItemClaim.assert_available!(item)
      offer = create_outline!(departure, arrangement, item, title, description, "undecided")
      audit_connection!(offer, offer.editable_draft_version, arrangement, version, item, "outlined")
      return offer
    end

    if @mode == "new"
      ensure_departure_accepts_new_offer!(departure)
      TypedItemClaim.assert_available!(item)
      offer = create_outline!(departure, arrangement, item, title, description, "m3_backed")
      offer_version = offer.editable_draft_version
    else
      offer = lock_offer_for!(@agency.service_offers.find(@attributes[:service_offer_id]))
      offer_version = lock_editable_offer_draft!(offer)
      ensure_offer_draft_editable!(departure, offer, offer_version)
      ensure_current_lock_version!(offer_version, @attributes[:version_lock_version])
      TypedItemClaim.assert_available!(item, except_offer: offer)
      offer.update!(intended_arrangement_item: item, intended_supplier_arrangement: arrangement)
      offer_version.definition.update!(client_title: title, client_description: description, fulfillment_basis: "m3_backed")
    end

    if resource_ids.empty?
      create_required_binding!(offer, offer_version, arrangement, version, item, item_definition, occurrence, occurrence_definition)
    else
      create_choices!(offer, offer_version, departure, arrangement, version, item, item_definition, occurrence, occurrence_definition, resource_ids)
    end
    bump_version!(offer_version)
    audit_connection!(offer, offer_version, arrangement, version, item, @mode == "new" ? "created" : "connected")
    offer
  end

  def create_outline!(departure, arrangement, item, title, description, fulfillment)
    offer = @agency.service_offers.create!(
      departure: departure, name: title, intended_arrangement_item: item, intended_supplier_arrangement: arrangement
    )
    version = offer.versions.create!(agency: @agency, departure: departure, version_number: 1, status: "draft")
    version.create_definition!(
      agency: @agency, departure: departure, service_offer: offer,
      client_title: title, client_description: description, fulfillment_basis: fulfillment
    )
    offer
  end

  def create_required_binding!(offer, offer_version, arrangement, version, item, item_definition, occurrence, occurrence_definition)
    pin = pin_for(arrangement, version, item, item_definition, occurrence, occurrence_definition)
    offer_version.source_bindings.create!(
      binding_attributes_from_pin(pin, membership: "required", position: 1).merge(service_offer: offer)
    )
  end

  def create_choices!(offer, offer_version, departure, arrangement, version, item, item_definition, occurrence, occurrence_definition, resource_ids)
    group = offer_version.choice_groups.create!(
      agency: @agency, departure: departure, service_offer: offer,
      name: @choice_group_name.presence || "Choice", min_selections: 1, max_selections: 1, position: 1
    )
    resource_ids.each_with_index do |resource_id, index|
      resource = item.supplier_resources.find(resource_id)
      resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource_id: resource.id)
      pin = pin_for(arrangement, version, item, item_definition, occurrence, occurrence_definition).merge(
        resource: resource, resource_definition: resource_definition
      )
      binding = offer_version.source_bindings.create!(
        binding_attributes_from_pin(pin, membership: "choice_gated", position: index + 1).merge(service_offer: offer)
      )
      option = group.service_offer_choice_options.create!(
        agency: @agency, departure: departure, service_offer: offer, service_offer_version: offer_version,
        name: resource_definition.name, client_description: nil, price_effect_minor_units: nil, position: index + 1
      )
      option.create_source_activation!(
        agency: @agency, departure: departure, service_offer: offer, service_offer_version: offer_version,
        activation_kind: "binding", service_offer_source_binding: binding
      )
    end
  end

  def pin_for(arrangement, version, item, item_definition, occurrence, occurrence_definition)
    {
      arrangement: arrangement, version: version, item: item, occurrence: occurrence,
      item_definition: item_definition, occurrence_definition: occurrence_definition,
      resource: nil, resource_definition: nil, pool: nil, pool_definition: nil
    }
  end

  def audit_connection!(offer, version, arrangement, arrangement_version, item, status)
    audit!(
      agency: @agency, action: "service_offer.updated", subject: offer, actor: @actor,
      details: {
        "service_offer_id" => offer.id, "service_offer_version_id" => version.id,
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => arrangement_version&.id,
        "arrangement_item_id" => item.id, "status" => status
      }.compact
    )
  end

  def public_status
    { "new" => :created, "existing" => :connected, "later" => :outlined }.fetch(@mode)
  end
end
