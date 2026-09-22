# frozen_string_literal: true

class DetectCruiseSupplierRateShape
  include CruiseSupplierRateSupport

  Result = Data.define(
    :compatible?,
    :empty?,
    :version,
    :item,
    :occurrence,
    :resource,
    :resource_definition,
    :source,
    :definition,
    :summary,
    :reasons
  )

  def initialize(agency:, arrangement:, resource:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @resource = resource
    @version = version
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = resolve_version!(arrangement)
    return empty_result(version, [ "No editable draft or governing version is available." ]) if version.nil?

    item_definition = version.arrangement_item_definitions.order(:position, :id).first
    occurrence_definition = version.service_occurrence_definitions.order(:id).first
    resource_definition = version.supplier_resource_definitions.find_by(supplier_resource_id: @resource.id)
    return empty_result(version, [ "That cabin category is not part of this Cruise." ]) if resource_definition.nil?

    item = resource_definition.arrangement_item
    resource = resource_definition.supplier_resource
    occurrence = occurrence_definition&.service_occurrence

    unless item_definition&.category == "cruise" && occurrence
      return empty_result(version, [ "Cruise sailing context is incomplete." ], resource_definition: resource_definition)
    end

    sources = version.supplier_cost_sources.where(
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    ).order(:position, :id).to_a

    if sources.empty?
      return Result.new(
        compatible?: true,
        empty?: true,
        version: version,
        item: item,
        occurrence: occurrence,
        resource: resource,
        resource_definition: resource_definition,
        source: nil,
        definition: nil,
        summary: {
          state: "missing",
          action: "add",
          maximum_occupancy: resource_definition.maximum_occupancy,
          supplier_code: resource_definition.supplier_code,
          name: resource_definition.name
        },
        reasons: []
      )
    end

    reasons = []
    reasons << "Cruise rates support one exact-context cost source per cabin category." if sources.size > 1
    source = sources.first
    definitions = source.supplier_cost_definitions.includes(supplier_cost_components: :supplier_cost_component_bases).order(:stage, :id).to_a
    by_stage = definitions.group_by(&:stage)
    by_stage.each do |stage, rows|
      if rows.size > 1
        reasons << "Cruise rates allow at most one #{stage} definition for this cabin category."
      end
    end

    # Prefer draft working definition for edits; otherwise governing forecast-ready or sole definition.
    definition = preferred_definition(definitions)
    if definition
      components = definition.supplier_cost_components.sort_by { |c| [ c.position, c.id ] }
      component_reasons = validate_components(components)
      reasons.concat(component_reasons)
    end

    if reasons.any?
      return Result.new(
        compatible?: false,
        empty?: false,
        version: version,
        item: item,
        occurrence: occurrence,
        resource: resource,
        resource_definition: resource_definition,
        source: source,
        definition: definition,
        summary: {
          state: "unsupported",
          action: "advanced",
          stage: definition&.stage,
          status: definition&.status,
          maximum_occupancy: resource_definition.maximum_occupancy,
          supplier_code: resource_definition.supplier_code,
          name: resource_definition.name
        },
        reasons: reasons.uniq
      )
    end

    Result.new(
      compatible?: true,
      empty?: false,
      version: version,
      item: item,
      occurrence: occurrence,
      resource: resource,
      resource_definition: resource_definition,
      source: source,
      definition: definition,
      summary: build_summary(resource_definition, definition, components_for(definition)),
      reasons: []
    )
  end

  private

  def resolve_version!(arrangement)
    return @version if @version

    arrangement.versions.find_by(status: "draft") || arrangement.governing_version
  end

  def preferred_definition(definitions)
    definitions.find { |d| d.working? } ||
      definitions.find { |d| d.forecast_ready? } ||
      definitions.first
  end

  def components_for(definition)
    return [] unless definition

    definition.supplier_cost_components.sort_by { |c| [ c.position, c.id ] }
  end

  def validate_components(components)
    reasons = []
    labels_seen = Hash.new(0)
    commission_count = 0

    components.each do |component|
      key = CruiseSupplierRateSupport.term_key_for_label(component.label)
      if key.nil?
        reasons << "Cruise rates cannot reopen noncanonical component “#{component.label}”."
        next
      end

      labels_seen[component.label] += 1
      if key == :commission
        commission_count += 1
        reasons.concat(validate_commission(component, components))
      else
        reasons.concat(validate_term(component, key))
      end

      if %w[minimum_amount_shortfall minimum_quantity_shortfall fixed].include?(component.calculation_kind)
        reasons << "Cruise rates do not support #{component.calculation_kind.tr('_', ' ')} components."
      end
    end

    labels_seen.each do |label, count|
      reasons << "Cruise rates allow only one “#{label}” component." if count > 1
    end
    reasons << "Cruise rates allow only one expected commission component." if commission_count > 1
    reasons
  end

  def validate_term(component, key)
    spec = CruiseSupplierRateSupport::CANONICAL_SPECS.fetch(key)
    reasons = []
    unless component.economic_role == spec.fetch(:economic_role)
      reasons << "“#{component.label}” must use the #{spec.fetch(:economic_role).tr('_', ' ')} role."
    end
    unless component.calculation_kind == spec.fetch(:calculation_kind)
      reasons << "“#{component.label}” must use a unit rate."
    end
    unless component.quantity_basis == spec.fetch(:quantity_basis)
      reasons << "“#{component.label}” uses an unsupported quantity basis."
    end
    if spec.key?(:occupancy_position_from)
      unless component.occupancy_position_from == spec[:occupancy_position_from] &&
          component.occupancy_position_to == spec[:occupancy_position_to]
        reasons << "“#{component.label}” uses unsupported occupancy positions."
      end
    end
    reasons
  end

  def validate_commission(component, all_components)
    reasons = []
    unless component.economic_role == "expected_commission"
      reasons << "Expected commission must use the expected commission role."
    end

    case component.calculation_kind
    when "unit_rate"
      unless %w[persons resource_units].include?(component.quantity_basis)
        reasons << "Dollar commission must apply per traveler or per cabin."
      end
      if component.supplier_cost_component_bases.any?
        reasons << "Dollar commission cannot carry percentage base links."
      end
    when "percentage"
      unless component.percentage_treatment == "additive"
        reasons << "Percentage commission must be additive."
      end
      bases = component.supplier_cost_component_bases.includes(:base_component).to_a
      if bases.empty?
        reasons << "Percentage commission requires explicit base components."
      else
        by_id = all_components.index_by(&:id)
        bases.each do |link|
          base = by_id[link.base_component_id] || link.base_component
          key = CruiseSupplierRateSupport.term_key_for_label(base.label)
          if key.nil? || key == :commission
            reasons << "Commission bases must be canonical rate components."
            break
          end
          if CruiseSupplierRateSupport::DISCOUNT_BASE_KEYS.include?(key) && link.direction != "subtract"
            reasons << "Discount commission bases must subtract."
          end
          if CruiseSupplierRateSupport::CHARGE_BASE_KEYS.include?(key) && link.direction != "add"
            reasons << "Charge commission bases must add."
          end
        end
      end
    else
      reasons << "Cruise rates support only dollar or percentage expected commission."
    end
    reasons
  end

  def build_summary(resource_definition, definition, components)
    commission = components.find { |c| c.label == CruiseSupplierRateSupport::COMMISSION_LABEL }
    commission_mode = if commission.nil?
      "not_provided"
    elsif commission.calculation_kind == "unit_rate"
      "dollar"
    else
      "percentage"
    end

    state = if definition.nil?
      "missing"
    elsif definition.forecast_ready?
      "forecast_ready"
    else
      "working"
    end

    {
      state: state,
      action: state == "forecast_ready" ? "review" : (state == "missing" ? "add" : "continue"),
      stage: definition&.stage,
      status: definition&.status,
      commission_mode: commission_mode,
      maximum_occupancy: resource_definition.maximum_occupancy,
      supplier_code: resource_definition.supplier_code,
      name: resource_definition.name
    }
  end

  def empty_result(version, reasons, resource_definition: nil)
    Result.new(
      compatible?: false,
      empty?: true,
      version: version,
      item: resource_definition&.arrangement_item,
      occurrence: nil,
      resource: resource_definition&.supplier_resource,
      resource_definition: resource_definition,
      source: nil,
      definition: nil,
      summary: { state: "unsupported", action: "advanced" },
      reasons: reasons
    )
  end
end
