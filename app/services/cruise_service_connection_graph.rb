# frozen_string_literal: true

module CruiseServiceConnectionGraph
  private

  def category_pins_for!(shape, arrangement_version, resource_ids)
    ids = Array(resource_ids).map(&:to_s).reject(&:blank?)
    raise AgencyCommand::Error.new("Choose at least one cabin category.", code: :invalid) if ids.empty?
    raise AgencyCommand::Error.new("Choose each cabin category once.", code: :invalid) if ids.uniq.size != ids.size

    version = arrangement_version
    item_definition = version.arrangement_item_definitions.find_by!(arrangement_item_id: shape.item.id)
    occurrence_definition = version.service_occurrence_definitions.find_by!(service_occurrence_id: shape.occurrence.id)
    resource_definitions = version.supplier_resource_definitions.where(supplier_resource_id: ids).index_by { |row| row.supplier_resource_id.to_s }
    pool_definitions = version.capacity_pool_definitions.includes(:capacity_pool).index_by { |row| row.supplier_resource_id.to_s }

    ids.map do |resource_id|
      resource_definition = resource_definitions[resource_id]
      pool_definition = pool_definitions[resource_id]
      pool = pool_definition&.capacity_pool
      unless resource_definition && CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
        raise AgencyCommand::Error.new("Choose cabin categories from this sailing.", code: :invalid)
      end

      {
        arrangement: shape.item.supplier_arrangement,
        version: version,
        item: shape.item,
        item_definition: item_definition,
        occurrence: shape.occurrence,
        occurrence_definition: occurrence_definition,
        resource: resource_definition.supplier_resource,
        resource_definition: resource_definition,
        pool: pool,
        pool_definition: pool_definition
      }
    end
  end

  def ensure_same_version_categories!(pinned_version, resource_ids)
    ids = Array(resource_ids).map(&:to_s)
    definitions = pinned_version.supplier_resource_definitions.where(supplier_resource_id: ids)
    return if definitions.size == ids.uniq.size

    raise AgencyCommand::Error.new("Choose cabin categories from the connected sailing version.", code: :invalid)
  end

  def create_choice_group!(offer, version, departure)
    version.choice_groups.create!(
      agency: @agency,
      departure: departure,
      service_offer: offer,
      name: CruiseServiceConnectionSupport::GROUP_NAME,
      min_selections: 1,
      max_selections: 1,
      position: 1
    )
  end

  def create_cabin_choice!(offer:, version:, departure:, group:, pin:, position:)
    binding = version.source_bindings.create!(
      binding_attributes_from_pin(pin, membership: "choice_gated", position: position)
        .merge(service_offer: offer)
    )
    option = group.service_offer_choice_options.new(
      agency: @agency,
      departure: departure,
      service_offer: offer,
      service_offer_version: version,
      name: CruiseServiceConnectionSupport.option_name_for(pin[:resource_definition]),
      client_description: nil,
      price_effect_minor_units: nil,
      position: position
    )
    option.client_rate_category_key = CruiseServiceConnectionSupport.rate_key_for(option.id)
    option.save!
    option.create_source_activation!(
      agency: @agency,
      departure: departure,
      service_offer: offer,
      service_offer_version: version,
      activation_kind: "binding",
      service_offer_source_binding: binding
    )
    option
  end

  def replace_positions!(records, final_positions, existing_max:, added_count:)
    base = [ existing_max.to_i, final_positions.values.max.to_i, 0 ].max + records.size + added_count + 1
    records.each_with_index do |record, index|
      record.update!(position: base + index)
    end
    records.each do |record|
      record.update!(position: final_positions.fetch(record.id))
    end
  end

  def refuse_priced_removals!(version, options)
    return if options.empty?

    keys = options.map(&:client_rate_category_key)
    priced = version.price_components.where(client_rate_category_key: keys).pluck(:client_rate_category_key)
    return if priced.empty?

    option = options.find { |row| priced.include?(row.client_rate_category_key) }
    raise AgencyCommand::Error.new(
      "Remove or retarget the Client price for #{option.name} before removing this cabin choice.",
      code: :invalid
    )
  end

  def claim_item!(offer, item, arrangement)
    offer.update!(
      intended_arrangement_item: item,
      intended_supplier_arrangement: arrangement
    )
  end

  def audit_connection!(offer, version, arrangement, arrangement_version, item, status)
    audit!(
      agency: @agency,
      action: "service_offer.cruise_connection_saved",
      subject: offer,
      actor: @actor,
      details: {
        "service_offer_id" => offer.id,
        "service_offer_version_id" => version.id,
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => arrangement_version&.id,
        "arrangement_item_id" => item.id,
        "status" => status.to_s
      }.compact
    )
  end
end
