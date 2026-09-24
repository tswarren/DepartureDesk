# frozen_string_literal: true

class CompileCruiseServiceConnectionWorkspace
  Category = Data.define(
    :resource, :resource_definition, :pool, :pool_definition,
    :selectable, :unavailable_reason, :selected, :option, :binding,
    :option_name, :supplier_label
  )
  Result = Data.define(
    :status, :offer, :version, :definition, :editable, :published,
    :connection, :categories, :eligible_offers, :reasons,
    :arrangement_version, :older_than_governing
  )

  def initialize(agency:, arrangement:, shape:)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
  end

  def call
    return unavailable("This Arrangement is not a supported cruise.") unless @shape.compatible?

    item = @shape.item
    offers = CruiseServiceConnectionSupport.offers_pinning_item(item)
    if offers.many?
      return advanced(offers, [ "More than one Client service already uses this cruise." ])
    end

    categories = category_rows(@shape.version)
    return not_connected(categories) if offers.empty?

    offer = offers.first
    version = live_version(offer)
    return advanced([ offer ], [ "This service has no live version." ]) if version.nil?

    definition = version.definition
    if definition&.undecided? && version.draft? && empty_graph?(version) && claim_matches?(offer, item)
      return decide_later(offer, version, definition, categories)
    end

    connection = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: offer, version: version).call
    unless connection.compatible?
      return advanced([ offer ], connection.reasons, offer: offer, version: version)
    end

    connected(offer, version, definition, connection)
  end

  private

  def not_connected(categories)
    Result.new(
      status: :not_connected,
      offer: nil,
      version: nil,
      definition: nil,
      editable: true,
      published: false,
      connection: nil,
      categories: mark_selection(categories, selected_ids: preselected_ids(categories)),
      eligible_offers: eligible_offers,
      reasons: [],
      arrangement_version: @shape.version,
      older_than_governing: false
    )
  end

  def decide_later(offer, version, definition, categories)
    Result.new(
      status: :decide_later,
      offer: offer,
      version: version,
      definition: definition,
      editable: true,
      published: false,
      connection: nil,
      categories: mark_selection(categories, selected_ids: []),
      eligible_offers: [],
      reasons: [],
      arrangement_version: @shape.version,
      older_than_governing: false
    )
  end

  def connected(offer, version, definition, connection)
    selected_ids = connection.choices.map { |choice| choice[:binding].supplier_resource_id }
    choices_by_resource = connection.choices.index_by { |choice| choice[:binding].supplier_resource_id }
    rows = mark_selection(category_rows(connection.arrangement_version), selected_ids: selected_ids).map do |category|
      choice = choices_by_resource[category.resource.id]
      next category if choice.nil?

      category.with(
        option: choice[:option],
        binding: choice[:binding],
        option_name: choice[:option].name
      )
    end
    governing = @arrangement.governing_version
    Result.new(
      status: :connected,
      offer: offer,
      version: version,
      definition: definition,
      editable: version.draft?,
      published: version.published?,
      connection: connection,
      categories: rows,
      eligible_offers: [],
      reasons: [],
      arrangement_version: connection.arrangement_version,
      older_than_governing: governing.present? && connection.arrangement_version&.id != governing.id && !connection.arrangement_version&.draft?
    )
  end

  def advanced(offers, reasons, offer: nil, version: nil)
    Result.new(
      status: :advanced,
      offer: offer || offers.first,
      version: version,
      definition: version&.definition,
      editable: false,
      published: version&.published? || false,
      connection: nil,
      categories: category_rows(@shape.version),
      eligible_offers: [],
      reasons: reasons,
      arrangement_version: @shape.version,
      older_than_governing: false
    )
  end

  def unavailable(reason)
    Result.new(
      status: :advanced,
      offer: nil,
      version: nil,
      definition: nil,
      editable: false,
      published: false,
      connection: nil,
      categories: [],
      eligible_offers: [],
      reasons: [ reason ],
      arrangement_version: @shape.version,
      older_than_governing: false
    )
  end

  def category_rows(version)
    return [] if version.nil?

    pool_definitions = version.capacity_pool_definitions.includes(:capacity_pool).index_by(&:supplier_resource_id)
    version.supplier_resource_definitions.includes(:supplier_resource).order(:position, :id).map do |resource_definition|
      pool_definition = pool_definitions[resource_definition.supplier_resource_id]
      pool = pool_definition&.capacity_pool
      selectable = CruiseCabinCategorySupport.typed_cabin_pool?(pool, pool_definition)
      Category.new(
        resource: resource_definition.supplier_resource,
        resource_definition: resource_definition,
        pool: pool,
        pool_definition: pool_definition,
        selectable: selectable,
        unavailable_reason: selectable ? nil : "Inventory not configured",
        selected: false,
        option: nil,
        binding: nil,
        option_name: nil,
        supplier_label: CruiseServiceConnectionSupport.option_name_for(resource_definition)
      )
    end
  end

  def mark_selection(categories, selected_ids:)
    categories.map { |category| category.with(selected: selected_ids.include?(category.resource.id)) }
  end

  def preselected_ids(categories)
    categories.select(&:selectable).map { |category| category.resource.id }
  end

  def live_version(offer)
    offer.editable_draft_version || offer.current_published_version
  end

  def empty_graph?(version)
    version.source_bindings.none? &&
      version.choice_groups.none? &&
      version.choice_options.none? &&
      ServiceOfferChoiceOptionSourceActivation.where(service_offer_version_id: version.id).none?
  end

  def claim_matches?(offer, item)
    offer.intended_arrangement_item_id.nil? || offer.intended_arrangement_item_id == item.id
  end

  def eligible_offers
    item_id = @shape.item.id
    @agency.service_offers.where(departure_id: @arrangement.departure_id).includes(versions: [ :definition, :source_bindings, :choice_groups, :choice_options ]).filter_map do |offer|
      version = offer.editable_draft_version
      next if version.nil? || version.owning_package_version_id.present?
      definition = version.definition
      next unless definition&.undecided?
      next if offer.intended_arrangement_item_id.present? && offer.intended_arrangement_item_id != item_id
      next unless empty_graph?(version)

      offer
    end
  end
end
