# frozen_string_literal: true

class DetectCruiseServiceConnectionShape
  Result = Data.define(
    :compatible?, :offer, :version, :definition, :arrangement, :arrangement_version,
    :item, :occurrence, :choices, :reasons
  )

  def initialize(agency:, offer:, version:)
    @agency = agency
    @offer = offer
    @version = version
  end

  def call
    offer = resolve_offer!
    version = offer.versions.find(@version.id)
    reasons = []
    reasons << "This version belongs to a Package." if version.owning_package_version_id.present?
    reasons << "Abandoned versions are not the live connection." if version.abandoned?
    definition = version.definition
    reasons << "The service definition is missing." if definition.nil?
    reasons << "Fulfillment is not backed by this cruise." if definition && !definition.m3_backed?

    groups = version.choice_groups.order(:position, :id).to_a
    options = version.choice_options.includes(:source_activation).order(:position, :id).to_a
    bindings = version.source_bindings.order(:position, :id).to_a
    reasons.concat(topology_reasons(groups, options, bindings))

    choices = []
    if reasons.empty?
      choices, choice_reasons = paired_choices(options, bindings)
      reasons.concat(choice_reasons)
    end

    cruise_reasons, arrangement, arrangement_version, item, occurrence = cruise_reasons_for(bindings)
    reasons.concat(cruise_reasons) if reasons.empty? || bindings.any?
    reasons.concat(claim_reasons(offer, arrangement, item))
    reasons = reasons.uniq

    Result.new(
      compatible?: reasons.empty?,
      offer: offer,
      version: version,
      definition: definition,
      arrangement: arrangement,
      arrangement_version: arrangement_version,
      item: item,
      occurrence: occurrence,
      choices: reasons.empty? ? choices : [],
      reasons: reasons
    )
  end

  private

  def resolve_offer!
    if @offer.is_a?(ServiceOffer) && @offer.agency_id == @agency.id
      return @offer
    end

    @agency.service_offers.find(@offer.id)
  end

  def topology_reasons(groups, options, bindings)
    reasons = []
    if groups.size != 1 || groups.first&.name != CruiseServiceConnectionSupport::GROUP_NAME
      reasons << "Cabin choices must use one Cabin category group."
    elsif groups.first.min_selections != 1 || groups.first.max_selections != 1
      reasons << "Cabin category must be an exactly-one choice."
    end
    reasons << "Cabin choices are missing." if options.empty?
    reasons << "Each cabin choice needs one source binding." if bindings.size != options.size
    reasons
  end

  def paired_choices(options, bindings)
    reasons = []
    choices = []
    seen_keys = {}
    bindings_by_id = bindings.index_by(&:id)
    used_binding_ids = []

    options.each do |option|
      activation = option.source_activation
      unless activation&.activation_binding? && activation.service_offer_source_binding_id.present?
        reasons << "Each cabin choice must activate its source binding."
        next
      end

      binding = bindings_by_id[activation.service_offer_source_binding_id]
      if binding.nil? || !binding.choice_gated?
        reasons << "Each cabin choice must activate a choice-gated source."
        next
      end
      used_binding_ids << binding.id
      reasons.concat(option_reasons(option, seen_keys))
      choices << { option: option, binding: binding }
    end

    if used_binding_ids.uniq.size != bindings.size
      reasons << "Every source binding must belong to one cabin choice."
    end
    [ choices, reasons ]
  end

  def option_reasons(option, seen_keys)
    reasons = []
    key = option.client_rate_category_key
    if key.blank? || key !~ CruiseServiceConnectionSupport::RATE_KEY_FORMAT
      reasons << "A cabin choice is missing its rate key."
    elsif seen_keys[key]
      reasons << "Cabin rate keys must be unique on this version."
    else
      seen_keys[key] = true
    end
    reasons << "A cabin choice has a price effect." if option.price_effect_minor_units.present?
    reasons << "A cabin choice has a client description." if option.client_description.present?
    reasons
  end

  def cruise_reasons_for(bindings)
    return [ [ "Cabin choices do not pin one cruise." ], nil, nil, nil, nil ] if bindings.empty?

    arrangement_ids = bindings.map(&:supplier_arrangement_id).uniq
    version_ids = bindings.map(&:supplier_arrangement_version_id).uniq
    item_ids = bindings.map(&:arrangement_item_id).uniq
    occurrence_ids = bindings.map(&:service_occurrence_id).uniq
    reasons = []
    reasons << "Cabin choices must pin one Arrangement version." if arrangement_ids.size != 1 || version_ids.size != 1
    reasons << "Cabin choices must pin one Arrangement Item." if item_ids.size != 1
    reasons << "Cabin choices must pin one sailing." if occurrence_ids.size != 1 || occurrence_ids.first.nil?
    return [ reasons, nil, nil, nil, nil ] if reasons.any?

    arrangement = @agency.supplier_arrangements.find_by(id: arrangement_ids.first)
    arrangement_version = arrangement&.versions&.find_by(id: version_ids.first)
    if arrangement.nil? || arrangement_version.nil? || arrangement.departure_id != @offer.departure_id
      return [ [ "The pinned cruise could not be found." ], arrangement, arrangement_version, nil, nil ]
    end

    shape = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: arrangement,
      version: arrangement_version
    ).call
    unless shape.compatible?
      return [ [ "The pinned Arrangement is not a supported cruise." ], arrangement, arrangement_version, shape.item, shape.occurrence ]
    end
    reasons << "Cabin choices pin a different cruise item." if item_ids.first != shape.item&.id
    reasons << "Cabin choices pin a different sailing." if occurrence_ids.first != shape.occurrence&.id

    bindings.each do |binding|
      reasons.concat(binding_reasons(binding, arrangement_version))
    end
    [ reasons, arrangement, arrangement_version, shape.item, shape.occurrence ]
  end

  def claim_reasons(offer, arrangement, item)
    return [] if arrangement.nil? || item.nil?
    return [] if offer.intended_arrangement_item_id.nil? && offer.intended_supplier_arrangement_id.nil?
    return [] if offer.intended_arrangement_item_id == item.id && offer.intended_supplier_arrangement_id == arrangement.id

    [ "The Cruise item claim does not match the cabin choices." ]
  end

  def binding_reasons(binding, arrangement_version)
    reasons = []
    reasons << "A cabin choice is missing its resource." if binding.supplier_resource_id.blank?
    reasons << "A cabin choice is missing its inventory pool." if binding.capacity_pool_id.blank?
    resource_definition = arrangement_version.supplier_resource_definitions.find_by(id: binding.supplier_resource_definition_id)
    pool = binding.capacity_pool
    pool_definition = arrangement_version.capacity_pool_definitions.find_by(id: binding.capacity_pool_definition_id)
    unless CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
      reasons << "A cabin choice does not pin a typed cabin pool."
    end
    if resource_definition.nil? || resource_definition.supplier_resource_id != binding.supplier_resource_id
      reasons << "A cabin choice does not pin the sailing resource."
    end
    if binding.service_occurrence_definition_id.blank? || binding.arrangement_item_definition_id.blank?
      reasons << "A cabin choice is missing a definition pin."
    end
    reasons
  end
end
