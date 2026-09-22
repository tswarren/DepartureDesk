# frozen_string_literal: true

class DetectCruiseSupplierRateShape
  include CruiseSupplierRateSupport

  Result = Data.define(
    :compatible?,
    :empty?,
    :legacy?,
    :matrix?,
    :version,
    :item,
    :occurrence,
    :resource,
    :resource_definition,
    :source,
    :definition,
    :summary,
    :reasons,
    :projected_matrix
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
        legacy?: false,
        matrix?: false,
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
        reasons: [],
        projected_matrix: empty_projected_matrix
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

    definition = preferred_definition(definitions)
    components = components_for(definition)
    legacy = definition && CruiseSupplierRateSupport.legacy_form?(components)
    matrix = definition && CruiseSupplierRateSupport.matrix_form?(components)

    if definition
      if matrix
        reasons.concat(validate_matrix_components(components))
      elsif legacy
        reasons.concat(validate_legacy_components(components))
      else
        reasons << "Cruise rates cannot reopen these Supplier cost terms as a typed matrix."
        reasons.concat(validate_unsupported_hints(components))
      end
    end

    if reasons.any?
      return Result.new(
        compatible?: false,
        empty?: false,
        legacy?: false,
        matrix?: false,
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
        reasons: reasons.uniq,
        projected_matrix: empty_projected_matrix
      )
    end

    projected = if matrix
      reconstruct_matrix(components)
    elsif legacy
      project_legacy_matrix(components)
    else
      empty_projected_matrix
    end

    Result.new(
      compatible?: true,
      empty?: false,
      legacy?: !!legacy && !matrix,
      matrix?: !!matrix,
      version: version,
      item: item,
      occurrence: occurrence,
      resource: resource,
      resource_definition: resource_definition,
      source: source,
      definition: definition,
      summary: build_summary(resource_definition, definition, components, legacy: legacy && !matrix, matrix: matrix),
      reasons: [],
      projected_matrix: projected
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

  def empty_projected_matrix
    {
      profiles: %i[first_second additional every_traveler single_supplement],
      cells: {},
      commission: { method: "not_provided" }
    }
  end

  def reconstruct_matrix(components)
    cells = {}
    profiles = []
    components.each do |component|
      next if component.economic_role == "expected_commission"

      row_key = CruiseSupplierRateSupport.static_row_key_for_label(component.label)
      profile_key = CruiseSupplierRateSupport.profile_key_for_component(component)
      next unless row_key && profile_key

      profiles << profile_key
      cells[CruiseSupplierRateSupport.cell_key(row_key, profile_key)] = component.amount_minor_units
    end
    {
      profiles: profiles.uniq.presence || empty_projected_matrix[:profiles],
      cells: cells,
      commission: reconstruct_commission(components, cells)
    }
  end

  def project_legacy_matrix(components)
    cells = {}
    profiles = []
    components.each do |component|
      next if component.economic_role == "expected_commission"

      pair = LEGACY_LABEL_TO_CELL[component.label]
      next unless pair

      row_key, profile_key = pair
      profiles << profile_key
      cells[CruiseSupplierRateSupport.cell_key(row_key, profile_key)] = component.amount_minor_units
    end
    {
      profiles: profiles.uniq.presence || empty_projected_matrix[:profiles],
      cells: cells,
      commission: project_legacy_commission(components, cells)
    }
  end

  def reconstruct_commission(components, cells)
    commissions = components.select { |c| c.economic_role == "expected_commission" }
    return { method: "not_provided" } if commissions.empty?

    if commissions.size == 1 && commissions.first.calculation_kind == "percentage"
      add_cells = []
      subtract_cells = []
      commissions.first.supplier_cost_component_bases.includes(:base_component).each do |link|
        base = link.base_component
        row_key = CruiseSupplierRateSupport.static_row_key_for_label(base.label)
        profile_key = CruiseSupplierRateSupport.profile_key_for_component(base)
        next unless row_key && profile_key

        cell = CruiseSupplierRateSupport.cell_key(row_key, profile_key)
        if link.direction == "subtract"
          subtract_cells << cell
        else
          add_cells << cell
        end
      end
      return {
        method: "percentage",
        rate: commissions.first.rate,
        percentage: (commissions.first.rate * 100),
        shared: true,
        add_cells: add_cells,
        subtract_cells: subtract_cells
      }
    end

    if commissions.all? { |c| c.calculation_kind == "unit_rate" }
      amounts = {}
      commissions.each do |component|
        profile_key = CruiseSupplierRateSupport.profile_key_for_component(component)
        profile_key ||= if component.quantity_basis == "resource_units"
          :every_cabin
        elsif component.quantity_basis == "persons"
          :every_traveler
        end
        next unless profile_key

        amounts[profile_key] = component.amount_minor_units
      end
      return { method: "dollar", amounts: amounts } if amounts.any?
    end

    { method: "not_provided" }
  end

  def project_legacy_commission(components, cells)
    commissions = components.select { |c| c.label == COMMISSION_LABEL || c.economic_role == "expected_commission" }
    return { method: "not_provided" } if commissions.empty?

    if commissions.size == 1 && commissions.first.calculation_kind == "percentage"
      add_cells = []
      subtract_cells = []
      commissions.first.supplier_cost_component_bases.includes(:base_component).each do |link|
        base = link.base_component
        pair = LEGACY_LABEL_TO_CELL[base.label]
        next unless pair

        cell = CruiseSupplierRateSupport.cell_key(*pair)
        if link.direction == "subtract"
          subtract_cells << cell
        else
          add_cells << cell
        end
      end
      return {
        method: "percentage",
        rate: commissions.first.rate,
        percentage: (commissions.first.rate * 100),
        shared: true,
        add_cells: add_cells,
        subtract_cells: subtract_cells
      }
    end

    if commissions.size == 1 && commissions.first.calculation_kind == "unit_rate"
      profile_key = if commissions.first.quantity_basis == "resource_units"
        :every_cabin
      else
        :every_traveler
      end
      return {
        method: "dollar",
        amounts: { profile_key => commissions.first.amount_minor_units }
      }
    end

    { method: "not_provided" }
  end

  def validate_matrix_components(components)
    reasons = []
    cell_keys = Hash.new(0)
    percentage_commissions = 0

    components.each do |component|
      if %w[minimum_amount_shortfall minimum_quantity_shortfall fixed].include?(component.calculation_kind)
        reasons << "Cruise rates do not support #{component.calculation_kind.tr('_', ' ')} components."
        next
      end

      if component.economic_role == "expected_commission"
        if component.calculation_kind == "percentage"
          percentage_commissions += 1
          reasons.concat(validate_matrix_percentage_commission(component, components))
        elsif component.calculation_kind == "unit_rate"
          unless CruiseSupplierRateSupport.profile_key_for_component(component) ||
              %w[persons resource_units].include?(component.quantity_basis)
            reasons << "Dollar commission must use a supported rate profile."
          end
        else
          reasons << "Cruise rates support only dollar or percentage expected commission."
        end
        next
      end

      row_key = CruiseSupplierRateSupport.static_row_key_for_label(component.label)
      profile_key = CruiseSupplierRateSupport.profile_key_for_component(component)
      if row_key.nil? || profile_key.nil?
        reasons << "Cruise rates cannot reopen component “#{component.label}” in the typed matrix."
        next
      end
      unless component.calculation_kind == "unit_rate"
        reasons << "“#{component.label}” must use a unit rate."
      end
      unless component.economic_role == CruiseSupplierRateSupport.static_row_role(row_key)
        reasons << "“#{component.label}” uses an unsupported economic role."
      end
      cell_keys[CruiseSupplierRateSupport.cell_key(row_key, profile_key)] += 1
    end

    cell_keys.each do |key, count|
      reasons << "Cruise rates allow only one amount for matrix cell #{key}." if count > 1
    end
    reasons << "Cruise rates allow only one shared percentage commission component." if percentage_commissions > 1
    reasons
  end

  def validate_matrix_percentage_commission(component, all_components)
    reasons = []
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
        row_key = CruiseSupplierRateSupport.static_row_key_for_label(base.label)
        profile_key = CruiseSupplierRateSupport.profile_key_for_component(base)
        if row_key.nil? || profile_key.nil?
          reasons << "Commission bases must be matrix rate cells."
          break
        end
        if CruiseSupplierRateSupport.static_row_role(row_key) == "supplier_credit" && link.direction != "subtract"
          reasons << "Discount commission bases must subtract."
        end
        if CruiseSupplierRateSupport.static_row_role(row_key) == "supplier_charge" && link.direction != "add"
          reasons << "Charge commission bases must add."
        end
      end
    end
    reasons
  end

  def validate_legacy_components(components)
    reasons = []
    labels_seen = Hash.new(0)
    commission_count = 0

    components.each do |component|
      if component.label == COMMISSION_LABEL || component.economic_role == "expected_commission"
        commission_count += 1
        reasons.concat(validate_legacy_commission(component, components))
        next
      end

      unless LEGACY_LABEL_TO_CELL.key?(component.label)
        reasons << "Cruise rates cannot reopen noncanonical component “#{component.label}”."
        next
      end
      labels_seen[component.label] += 1
      pair = LEGACY_LABEL_TO_CELL.fetch(component.label)
      profile = PROFILE_FAMILIES.fetch(pair[1])
      row = STATIC_ROWS.fetch(pair[0])
      unless component.economic_role == row.fetch(:economic_role)
        reasons << "“#{component.label}” must use the #{row.fetch(:economic_role).tr('_', ' ')} role."
      end
      unless component.calculation_kind == "unit_rate"
        reasons << "“#{component.label}” must use a unit rate."
      end
      unless component.quantity_basis == profile.fetch(:quantity_basis)
        reasons << "“#{component.label}” uses an unsupported quantity basis."
      end
      if profile.key?(:occupancy_position_from)
        unless component.occupancy_position_from == profile[:occupancy_position_from] &&
            component.occupancy_position_to == profile[:occupancy_position_to]
          reasons << "“#{component.label}” uses unsupported occupancy positions."
        end
      end
    end

    labels_seen.each do |label, count|
      reasons << "Cruise rates allow only one “#{label}” component." if count > 1
    end
    reasons << "Cruise rates allow only one expected commission component." if commission_count > 1
    reasons
  end

  def validate_legacy_commission(component, all_components)
    reasons = []
    unless component.economic_role == "expected_commission"
      reasons << "Expected commission must use the expected commission role."
    end

    case component.calculation_kind
    when "unit_rate"
      unless %w[persons resource_units].include?(component.quantity_basis)
        reasons << "Dollar commission must apply per traveler or per cabin."
      end
    when "percentage"
      unless component.percentage_treatment == "additive"
        reasons << "Percentage commission must be additive."
      end
      if component.supplier_cost_component_bases.empty?
        reasons << "Percentage commission requires explicit base components."
      end
    else
      reasons << "Cruise rates support only dollar or percentage expected commission."
    end
    reasons
  end

  def validate_unsupported_hints(components)
    components.map do |component|
      "Unsupported component “#{component.label}” (#{component.calculation_kind})."
    end.first(3)
  end

  def build_summary(resource_definition, definition, components, legacy:, matrix:)
    commissions = components.select { |c| c.economic_role == "expected_commission" }
    commission_mode = if commissions.empty?
      "not_provided"
    elsif commissions.any? { |c| c.calculation_kind == "percentage" }
      "percentage"
    else
      "dollar"
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
      legacy: legacy,
      matrix: matrix,
      maximum_occupancy: resource_definition.maximum_occupancy,
      supplier_code: resource_definition.supplier_code,
      name: resource_definition.name
    }
  end

  def empty_result(version, reasons, resource_definition: nil)
    Result.new(
      compatible?: false,
      empty?: true,
      legacy?: false,
      matrix?: false,
      version: version,
      item: resource_definition&.arrangement_item,
      occurrence: nil,
      resource: resource_definition&.supplier_resource,
      resource_definition: resource_definition,
      source: nil,
      definition: nil,
      summary: { state: "unsupported", action: "advanced" },
      reasons: reasons,
      projected_matrix: empty_projected_matrix
    )
  end
end
