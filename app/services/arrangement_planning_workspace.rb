class ArrangementPlanningWorkspace
  include Rails.application.routes.url_helpers

  MAX_NEXT_ACTIONS = 6
  QUANTITY_WARNING_LABELS = {
    missing_usage_assumption: "Add planning quantities",
    missing_resource_units: "Add expected resource units",
    missing_persons: "Add expected persons",
    missing_billable_nights: "Add expected billable nights",
    missing_occupancy_profiles: "Define anonymous occupancy patterns"
  }.freeze

  Action = Data.define(:label, :text, :href, :target_item_id)

  def initialize(
    departure:, arrangement:, version:, item_definitions:,
    occurrence_definitions_by_item_id:, resource_definitions_by_item_id:,
    capacity_pairs_by_item_members:, capacity_pool_definitions_by_item_pair_id:,
    cost_sources_by_item_id:, forecast:, manageable:
  )
    @departure = departure
    @arrangement = arrangement
    @version = version
    @item_definitions = item_definitions
    @occurrences_by_item = occurrence_definitions_by_item_id
    @resources_by_item = resource_definitions_by_item_id
    @pairs_by_item = capacity_pairs_by_item_members
    @pools_by_item_pair = capacity_pool_definitions_by_item_pair_id
    @cost_sources_by_item = cost_sources_by_item_id
    @forecast = forecast
    @manageable = manageable
  end

  def next_actions
    @next_actions ||= all_actions.first(MAX_NEXT_ACTIONS)
  end

  def all_actions
    @all_actions ||= begin
      actions = []
      actions.concat(structure_actions)
      actions.concat(capacity_actions)
      actions.concat(cost_actions)
      actions
    end
  end

  def primary_action_for(item_id)
    all_actions.find { |action| action.target_item_id == item_id } ||
      Action.new(
        label: "Review Item costs",
        text: "Review the entered cost terms and planning quantities for this Item.",
        href: item_costs_path(item_id),
        target_item_id: item_id
      )
  end

  def structure_summary
    return "No Items have been added." if @item_definitions.empty?

    incomplete = @item_definitions.count do |definition|
      occurrences(definition).empty? || resources(definition).empty?
    end
    return "#{incomplete} of #{@item_definitions.size} Items need an Occurrence or Resource." if incomplete.positive?

    "#{@item_definitions.size} Items have Occurrence and Resource structure."
  end

  def capacity_summary
    return "No Items require a capacity applicability decision yet." if @item_definitions.empty?

    undecided_items = @item_definitions.count { |definition| definition.capacity_management.blank? }
    if undecided_items.positive?
      return "#{undecided_items} #{'Item'.pluralize(undecided_items)} still need a capacity applicability decision."
    end

    remaining_pairs = @item_definitions.sum { |definition| undecided_pair_count(definition) }
    return "#{remaining_pairs} eligible Occurrence–Resource pairs still need classification." if remaining_pairs.positive?

    missing_pools = @item_definitions.sum { |definition| pooled_pairs_without_pools(definition).size }
    return "#{missing_pools} pooled pairs still need a Pool." if missing_pools.positive?

    managed = @item_definitions.count(&:managed?)
    "#{managed} managed-capacity Items have pair decisions; #{@item_definitions.size - managed} are intentionally unmanaged."
  end

  def cost_summary
    return "Declared-cost forecast is ready; costs not entered here are not inferred." if @forecast.complete

    parts = []
    uncovered_count = @forecast.uncovered_item_ids.size
    incomplete_count = @forecast.incomplete_source_ids.size
    parts << "#{uncovered_count} #{'Item'.pluralize(uncovered_count)} lack an Item-scoped cost source" if uncovered_count.positive?
    if incomplete_count.positive?
      parts << "#{incomplete_count} entered #{'source'.pluralize(incomplete_count)} #{incomplete_count == 1 ? 'is' : 'are'} not forecast ready"
    end
    "#{parts.to_sentence.presence || "Entered cost facts are incomplete"}. Missing real-world costs are not treated as zero."
  end

  private

  def structure_actions
    if @item_definitions.empty?
      return [] unless @manageable

      return [
        Action.new(
          label: "Add the first Item",
          text: "Start the Arrangement structure with an Item and optional first Occurrence and Resource.",
          href: new_item_setup_path,
          target_item_id: nil
        )
      ]
    end

    @item_definitions.filter_map do |definition|
      missing_occurrence = occurrences(definition).empty?
      missing_resource = resources(definition).empty?
      next unless missing_occurrence || missing_resource

      item_id = definition.arrangement_item_id
      label = if @manageable
        missing_occurrence ? "Add an Occurrence for #{definition.name}" : "Add a Resource for #{definition.name}"
      else
        "Review structure for #{definition.name}"
      end
      href = if @manageable && missing_occurrence
        new_departure_arrangement_item_occurrence_path(@departure, @arrangement, item_id)
      elsif @manageable
        new_departure_arrangement_item_resource_path(@departure, @arrangement, item_id)
      else
        arrangement_path(structure_mode: "edit", structure_item_id: item_id)
      end
      missing = [ ("an Occurrence" if missing_occurrence), ("a Resource" if missing_resource) ].compact.to_sentence
      Action.new(
        label: label,
        text: "#{definition.name} needs #{missing} before its planning structure is usable.",
        href: href,
        target_item_id: item_id
      )
    end
  end

  def capacity_actions
    @item_definitions.flat_map do |definition|
      item_id = definition.arrangement_item_id
      path = item_capacity_path(item_id)
      if definition.capacity_management.blank?
        [
          Action.new(
            label: @manageable ? "Decide capacity for #{definition.name}" : "Review capacity for #{definition.name}",
            text: "Choose whether Supplier capacity is managed or intentionally not tracked.",
            href: path,
            target_item_id: item_id
          )
        ]
      elsif definition.managed? && undecided_pair_count(definition).positive?
        count = undecided_pair_count(definition)
        [
          Action.new(
            label: @manageable ? "Classify #{count} remaining capacity #{'pair'.pluralize(count)}" : "Review capacity decisions for #{definition.name}",
            text: "#{definition.name} has #{count} eligible Occurrence–Resource #{'pair'.pluralize(count)} without a decision.",
            href: path,
            target_item_id: item_id
          )
        ]
      elsif definition.managed? && pooled_pairs_without_pools(definition).any?
        [
          Action.new(
            label: @manageable ? "Add a Pool for #{definition.name}" : "Review pooled capacity for #{definition.name}",
            text: "A pooled Occurrence–Resource pair has no Pool definition.",
            href: path,
            target_item_id: item_id
          )
        ]
      else
        pool_warning_action(definition, path)
      end
    end
  end

  def cost_actions
    forecast_sources = @forecast.sources.index_by(&:source_id)
    actions = @item_definitions.filter_map do |definition|
      item_id = definition.arrangement_item_id
      if @forecast.uncovered_item_ids.include?(item_id)
        Action.new(
          label: @manageable ? "Add an Item cost for #{definition.name}" : "Review costs for #{definition.name}",
          text: "#{definition.name} has no Item-scoped cost source. This detects entered planning coverage only.",
          href: @manageable ? new_item_cost_setup_path(item_id) : item_costs_path(item_id),
          target_item_id: item_id
        )
      else
        incomplete_cost_action(definition, forecast_sources)
      end
    end
    actions + arrangement_cost_actions(forecast_sources)
  end

  def incomplete_cost_action(definition, forecast_sources)
    item_id = definition.arrangement_item_id
    source = Array(@cost_sources_by_item[item_id]).find do |candidate|
      @forecast.incomplete_source_ids.include?(candidate.id)
    end
    return unless source

    result = forecast_sources[source.id]
    quantity_warning = result&.warnings&.find { |warning| QUANTITY_WARNING_LABELS.key?(warning[:code]) }
    if quantity_warning
      Action.new(
        label: "#{QUANTITY_WARNING_LABELS.fetch(quantity_warning[:code])} for #{source.label}",
        text: quantity_warning[:message],
        href: item_costs_path(item_id),
        target_item_id: item_id
      )
    else
      definition_record = preferred_working_definition(source)
      Action.new(
        label: definition_record ? "Review #{definition_record.stage} terms for #{source.label}" : "Complete a cost stage for #{source.label}",
        text: result&.warnings&.first&.fetch(:message, nil) || "This entered source has no forecast-ready stage.",
        href: definition_record ? definition_review_path(source, definition_record, item_id) : item_costs_path(item_id),
        target_item_id: item_id
      )
    end
  end

  def arrangement_cost_actions(forecast_sources)
    source = @cost_sources_by_item.fetch(nil, []).find do |candidate|
      @forecast.incomplete_source_ids.include?(candidate.id)
    end
    return [] unless source

    definition = preferred_working_definition(source)
    result = forecast_sources[source.id]
    [
      Action.new(
        label: definition ? "Review #{definition.stage} terms for #{source.label}" : "Complete #{source.label}",
        text: result&.warnings&.first&.fetch(:message, nil) || "This Arrangement-wide source has no forecast-ready stage.",
        href: definition ? definition_review_path(source, definition, nil) : arrangement_costs_path,
        target_item_id: nil
      )
    ]
  end

  def pool_warning_action(definition, path)
    pool = pools(definition).find do |pool_definition|
      pool_definition.capacity_pool.supplying_supplier.inactive? ||
        (pool_definition.capacity_pool.numeric_inventory? &&
          (!pool_definition.override? &&
            (pool_definition.evidence_kind.blank? || pool_definition.evidence_on.blank? ||
              pool_definition.evidence_reference_note.blank?)))
    end
    return [] unless pool

    [
      Action.new(
        label: @manageable ? "Complete Supplier evidence for #{pool.label}" : "Review #{pool.label}",
        text: "This Pool has incomplete or inactive Supplier evidence.",
        href: path,
        target_item_id: definition.arrangement_item_id
      )
    ]
  end

  def preferred_working_definition(source)
    source.supplier_cost_definitions
      .reject(&:forecast_ready?)
      .min_by { |definition| [ definition.contracted? ? 0 : 1, definition.id ] }
  end

  def occurrences(definition)
    Array(@occurrences_by_item[definition.arrangement_item_id])
  end

  def active_occurrences(definition)
    occurrences(definition).reject { |entry| entry.service_occurrence.cancelled? }
  end

  def resources(definition)
    Array(@resources_by_item[definition.arrangement_item_id])
  end

  def pairs(definition)
    @pairs_by_item.fetch(definition.arrangement_item_id, {})
  end

  def pools(definition)
    @pools_by_item_pair.fetch(definition.arrangement_item_id, {}).values.flatten
  end

  def eligible_pair_keys(definition)
    active_occurrences(definition).product(resources(definition)).map do |occurrence, resource|
      [ occurrence.service_occurrence_id, resource.supplier_resource_id ]
    end
  end

  def undecided_pair_count(definition)
    return 0 unless definition.managed?

    eligible_pair_keys(definition).count { |key| pairs(definition)[key].nil? }
  end

  def pooled_pairs_without_pools(definition)
    pairs(definition).values.select do |pair|
      pair.pooled? && @pools_by_item_pair.fetch(definition.arrangement_item_id, {}).fetch(pair.id, []).empty?
    end
  end

  def arrangement_path(**options)
    departure_arrangement_path(@departure, @arrangement, **options)
  end

  def new_item_setup_path
    departure_arrangement_new_item_setup_path(@departure, @arrangement)
  end

  def item_capacity_path(item_id)
    departure_arrangement_item_capacity_path(@departure, @arrangement, item_id)
  end

  def item_costs_path(item_id)
    departure_arrangement_item_costs_workspace_path(@departure, @arrangement, item_id)
  end

  def arrangement_costs_path
    departure_arrangement_costs_workspace_path(@departure, @arrangement)
  end

  def new_item_cost_setup_path(item_id)
    departure_arrangement_item_new_cost_setup_path(@departure, @arrangement, item_id)
  end

  def definition_review_path(source, definition, item_id)
    if item_id
      departure_arrangement_item_cost_definition_review_path(
        @departure, @arrangement, item_id, source, definition
      )
    else
      departure_arrangement_cost_definition_review_path(
        @departure, @arrangement, source, definition
      )
    end
  end
end
