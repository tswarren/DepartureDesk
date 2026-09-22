# frozen_string_literal: true

# Builder helpers for Cruise Supplier rate matrix (Slice 2A.2R).
# Requires CostCommandSupport and an @agency / @actor context.
module CruiseSupplierRateBuilders
  include CruiseSupplierRateSupport

  private

  def resolve_cruise_rate_context!(arrangement, version, resource_id)
    item_definition = version.arrangement_item_definitions.order(:position, :id).sole
    unless item_definition.category == "cruise"
      raise AgencyCommand::Error.new("That arrangement is not a Cruise sailing setup.", code: :invalid_state)
    end
    occurrence_definition = version.service_occurrence_definitions.order(:id).sole
    resource_definition = version.supplier_resource_definitions.lock.find_by!(supplier_resource_id: resource_id)
    item = lock_item_cost_context!(
      arrangement, version,
      item: item_definition.arrangement_item,
      occurrence: occurrence_definition.service_occurrence,
      resource: resource_definition.supplier_resource
    )
    [ item_definition, occurrence_definition, resource_definition, *item ]
  end

  def find_exact_context_source(version, item:, occurrence:, resource:)
    version.supplier_cost_sources.find_by(
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    )
  end

  # Normalized matrix: { profiles:, cells:, commission:, convert_legacy: }
  # cells: { "base_fare:first_second" => amount_minor_or_nil, ... }
  def normalize_matrix_payload(profiles:, cells:, commission:, currency:, convert_legacy: false)
    profile_keys = Array(profiles).map(&:to_sym).uniq
    profile_keys = default_smith_profiles if profile_keys.empty?
    unknown_profiles = profile_keys - PROFILE_FAMILIES.keys
    if unknown_profiles.any?
      raise AgencyCommand::Error.new("Unsupported rate profile.", code: :invalid)
    end

    input = cells.to_h.with_indifferent_access
    normalized_cells = {}
    input.each do |raw_key, raw_amount|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(raw_key)
      unless STATIC_ROWS.key?(row_key) && PROFILE_FAMILIES.key?(profile_key)
        raise AgencyCommand::Error.new("Unknown rate matrix cell.", code: :invalid)
      end
      unless profile_keys.include?(profile_key)
        raise AgencyCommand::Error.new("Rate cell uses a profile that is not selected.", code: :invalid)
      end
      amount = money_minor_or_nil(
        raw_amount, currency, CruiseSupplierRateSupport.static_row_label(row_key), major_units: true
      )
      next if amount.nil?

      normalized_cells[CruiseSupplierRateSupport.cell_key(row_key, profile_key)] = amount
    end

    {
      profiles: profile_keys,
      cells: normalized_cells,
      commission: normalize_matrix_commission(commission, currency, profile_keys, normalized_cells),
      convert_legacy: convert_legacy == true || convert_legacy.to_s == "true" || convert_legacy.to_s == "1"
    }
  end

  def default_smith_profiles
    %i[first_second additional every_traveler single_supplement]
  end

  def normalize_matrix_commission(commission, currency, profile_keys, cells)
    input = (commission || {}).to_h.with_indifferent_access
    method = (input[:method].presence || "not_provided").to_s
    unless COMMISSION_METHODS.include?(method)
      raise AgencyCommand::Error.new("Choose how expected commission is stated.", code: :invalid)
    end

    case method
    when "not_provided"
      { method: method }
    when "dollar"
      amounts = {}
      raw_amounts = (input[:amounts] || {}).to_h.with_indifferent_access
      if raw_amounts.empty? && (input.key?(:amount) || input.key?(:amount_minor_units))
        # Legacy single dollar → Every Traveler / Every Cabin from applies_per.
        basis = input[:applies_per].presence || input[:quantity_basis].presence
        basis = "persons" if basis.to_s == "traveler"
        basis = "resource_units" if basis.to_s == "cabin"
        profile_key = basis.to_s == "resource_units" ? :every_cabin : :every_traveler
        amount = money_minor_or_nil(
          input.key?(:amount) ? input[:amount] : input[:amount_minor_units],
          currency, "Commission amount", major_units: input.key?(:amount)
        )
        raise AgencyCommand::Error.new("Enter the commission amount.", code: :invalid) if amount.nil?
        amounts[profile_key] = amount
        profile_keys = (profile_keys + [ profile_key ]).uniq
      else
        raw_amounts.each do |profile_key, raw|
          key = profile_key.to_sym
          unless PROFILE_FAMILIES.key?(key)
            raise AgencyCommand::Error.new("Dollar commission uses an unsupported profile.", code: :invalid)
          end
          amount = money_minor_or_nil(raw, currency, "Commission amount", major_units: true)
          next if amount.nil?

          amounts[key] = amount
        end
        raise AgencyCommand::Error.new("Enter at least one dollar commission amount.", code: :invalid) if amounts.empty?
      end
      { method: method, amounts: amounts }
    when "percentage"
      rate = if input.key?(:percentage)
        percent = decimal_or_nil(input[:percentage], "Commission percentage")
        raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if percent.nil?
        percent / 100
      else
        decimal_or_nil(input[:rate], "Commission rate").tap do |value|
          raise AgencyCommand::Error.new("Enter the commission percentage.", code: :invalid) if value.nil?
        end
      end
      add_keys = Array(input[:add_bases] || input[:add_cells]).map(&:to_s)
      subtract_keys = Array(input[:subtract_bases] || input[:subtract_cells]).map(&:to_s)
      # Accept legacy term keys and map to matrix cell keys when cells present.
      add_keys = expand_legacy_commission_bases(add_keys, cells, :charge)
      subtract_keys = expand_legacy_commission_bases(subtract_keys, cells, :credit)
      unknown = (add_keys + subtract_keys).reject { |key| cells.key?(key) }
      if unknown.any?
        raise AgencyCommand::Error.new("Commission bases must match populated rate cells.", code: :invalid)
      end
      if add_keys.empty? && subtract_keys.empty?
        raise AgencyCommand::Error.new("Select at least one commission base.", code: :invalid)
      end
      {
        method: method,
        rate: rate,
        shared: true,
        add_cells: add_keys,
        subtract_cells: subtract_keys
      }
    end
  end

  def expand_legacy_commission_bases(keys, cells, role)
    keys.flat_map do |key|
      next [ key ] if cells.key?(key)

      # Map old term keys (first_second_fare) onto matrix cells.
      mapped = legacy_term_key_to_cell_keys(key.to_sym, role)
      mapped.select { |cell| cells.key?(cell) }
    end.uniq
  end

  def legacy_term_key_to_cell_keys(term_key, role)
    mapping = {
      first_second_fare: [ "base_fare:first_second" ],
      additional_fare: [ "base_fare:additional" ],
      single_supplement: [ "base_fare:single_supplement" ],
      nccf: [ "nccf:every_traveler" ],
      taxes_fees: [ "taxes_fees:every_traveler" ],
      first_second_discount: [ "discount:first_second" ],
      additional_discount: [ "discount:additional" ]
    }
    mapping.fetch(term_key, [])
  end

  def component_attributes_for_cell(row_key, profile_key, amount_minor_units)
    row = STATIC_ROWS.fetch(row_key)
    profile = PROFILE_FAMILIES.fetch(profile_key)
    {
      label: row.fetch(:label),
      economic_role: row.fetch(:economic_role),
      calculation_kind: "unit_rate",
      amount_minor_units: amount_minor_units,
      quantity_basis: profile.fetch(:quantity_basis),
      occupancy_position_from: profile[:occupancy_position_from],
      occupancy_position_to: profile[:occupancy_position_to],
      percentage_treatment: nil,
      participant_category_id: nil,
      pass_through: false,
      rate: nil,
      minimum_minor_units: nil,
      minimum_quantity: nil
    }
  end

  def find_component_for_cell(components, row_key, profile_key)
    label = STATIC_ROWS.fetch(row_key).fetch(:label)
    profile = PROFILE_FAMILIES.fetch(profile_key)
    components.find do |component|
      component.label == label &&
        component.economic_role == STATIC_ROWS.fetch(row_key).fetch(:economic_role) &&
        component.quantity_basis == profile.fetch(:quantity_basis) &&
        component.occupancy_position_from == profile[:occupancy_position_from] &&
        component.occupancy_position_to == profile[:occupancy_position_to] &&
        component.participant_category_id.nil? &&
        component.economic_role != "expected_commission"
    end
  end

  def find_legacy_component_for_cell(components, row_key, profile_key)
    LEGACY_LABEL_TO_CELL.each do |legacy_label, pair|
      next unless pair == [ row_key, profile_key ]

      return components.find { |c| c.label == legacy_label }
    end
    nil
  end

  def sync_matrix_components!(definition, matrix:, converting_legacy: false)
    components = definition.supplier_cost_components.lock.to_a
    cell_to_component = {}
    position = 1
    kept_ids = []

    matrix.fetch(:cells).each do |cell_key, amount|
      row_key, profile_key = CruiseSupplierRateSupport.parse_cell_key(cell_key)
      attrs = component_attributes_for_cell(row_key, profile_key, amount)
      existing = find_component_for_cell(components, row_key, profile_key)
      if existing.nil? && converting_legacy
        existing = find_legacy_component_for_cell(components, row_key, profile_key)
      end

      component = if existing
        existing.update!(attrs.merge(position: position))
        existing
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      cell_to_component[cell_key] = component
      kept_ids << component.id
      position += 1
    end

    # Remove charge/credit components that are no longer populated (matrix or legacy labels).
    components.each do |component|
      next if component.economic_role == "expected_commission"
      next if kept_ids.include?(component.id)

      destroy_component_and_dependent_bases!(definition, component)
    end

    sync_matrix_commission!(definition, matrix.fetch(:commission), cell_to_component, position)
    renumber_components!(definition)
    touch_definition_after_change!(definition)
  end

  def sync_matrix_commission!(definition, commission, cell_to_component, start_position)
    components = definition.supplier_cost_components.reload.lock.to_a
    commission_components = components.select { |c| c.economic_role == "expected_commission" }

    if commission.fetch(:method) == "not_provided"
      commission_components.each { |c| destroy_component_and_dependent_bases!(definition, c) }
      return
    end

    if commission.fetch(:method) == "percentage"
      # Shared percentage: exactly one component.
      attrs = {
        label: COMMISSION_LABEL,
        economic_role: "expected_commission",
        calculation_kind: "percentage",
        rate: commission.fetch(:rate),
        percentage_treatment: "additive",
        pass_through: false,
        amount_minor_units: nil,
        quantity_basis: nil,
        occupancy_position_from: nil,
        occupancy_position_to: nil,
        participant_category_id: nil,
        minimum_minor_units: nil,
        minimum_quantity: nil
      }
      primary = commission_components.first
      (commission_components - [ primary ].compact).each do |extra|
        destroy_component_and_dependent_bases!(definition, extra)
      end
      commission_component = if primary
        primary.update!(attrs.merge(position: start_position))
        primary
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: start_position, base_links: []
        )
      end
      links = []
      commission.fetch(:add_cells).each do |cell_key|
        component = cell_to_component[cell_key]
        raise AgencyCommand::Error.new(
          "Select commission bases that are present on the rate schedule.", code: :invalid
        ) unless component

        links << { base_component_id: component.id, direction: "add", position: links.size + 1 }
      end
      commission.fetch(:subtract_cells).each do |cell_key|
        component = cell_to_component[cell_key]
        raise AgencyCommand::Error.new(
          "Select commission bases that are present on the rate schedule.", code: :invalid
        ) unless component

        links << { base_component_id: component.id, direction: "subtract", position: links.size + 1 }
      end
      replace_base_links!(definition, commission_component, links)
      return
    end

    # Dollar: one component per profile amount.
    # Destroy obsolete commission rows first so label uniqueness is not violated
    # when switching traveler ↔ cabin (or profile) bases.
    amounts = commission.fetch(:amounts)
    keep_signatures = amounts.keys.map { |profile_key| PROFILE_FAMILIES.fetch(profile_key) }
    commission_components.each do |component|
      next unless component.calculation_kind == "unit_rate"

      matching = keep_signatures.any? do |profile|
        component.quantity_basis == profile.fetch(:quantity_basis) &&
          component.occupancy_position_from == profile[:occupancy_position_from] &&
          component.occupancy_position_to == profile[:occupancy_position_to]
      end
      destroy_component_and_dependent_bases!(definition, component) unless matching
    end
    commission_components = definition.supplier_cost_components.reload.lock.select { |c|
      c.economic_role == "expected_commission"
    }

    used_ids = []
    position = start_position
    amounts.each do |profile_key, amount|
      profile = PROFILE_FAMILIES.fetch(profile_key)
      attrs = {
        label: COMMISSION_LABEL,
        economic_role: "expected_commission",
        calculation_kind: "unit_rate",
        amount_minor_units: amount,
        quantity_basis: profile.fetch(:quantity_basis),
        occupancy_position_from: profile[:occupancy_position_from],
        occupancy_position_to: profile[:occupancy_position_to],
        participant_category_id: nil,
        pass_through: false,
        rate: nil,
        percentage_treatment: nil,
        minimum_minor_units: nil,
        minimum_quantity: nil
      }
      existing = commission_components.find do |c|
        c.calculation_kind == "unit_rate" &&
          c.quantity_basis == profile.fetch(:quantity_basis) &&
          c.occupancy_position_from == profile[:occupancy_position_from] &&
          c.occupancy_position_to == profile[:occupancy_position_to] &&
          !used_ids.include?(c.id)
      end
      component = if existing
        existing.update!(attrs.merge(position: position))
        replace_base_links!(definition, existing, [])
        existing
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      used_ids << component.id
      position += 1
    end
    commission_components.each do |component|
      next if used_ids.include?(component.id)

      destroy_component_and_dependent_bases!(definition, component)
    end
  end

  def destroy_component_and_dependent_bases!(definition, component)
    return if component.nil?

    definition.supplier_cost_components.includes(:supplier_cost_component_bases).find_each do |other|
      other.supplier_cost_component_bases.where(base_component_id: component.id).lock.each(&:destroy!)
    end
    component.supplier_cost_component_bases.order(:id).lock.each(&:destroy!)
    component.destroy!
  end

  def renumber_components!(definition)
    definition.supplier_cost_components.order(:position, :id).lock.each_with_index do |component, index|
      component.update!(position: index + 1) if component.position != index + 1
    end
  end

  def clear_readiness_for_context!(version, item:, occurrence:, resource:)
    sources = version.supplier_cost_sources.where(
      arrangement_item_id: item.id,
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    )
    sources.find_each do |source|
      source.supplier_cost_definitions.lock.each { |definition| clear_readiness!(definition) }
    end
  end

  def ensure_traveler_category!(version, item:)
    version.supplier_cost_participant_categories.find_or_initialize_by(
      arrangement_item_id: item.id, label: PARTICIPANT_CATEGORY_LABEL
    ).tap do |category|
      if category.new_record?
        siblings = version.supplier_cost_participant_categories.where(arrangement_item: item).order(:position, :id).lock.to_a
        category.assign_attributes(
          owner_attributes_for(version).merge(position: siblings.map(&:position).max.to_i + 1)
        )
        category.save!
      end
    end
  end

  # Smith matrix helper used by tests and default create payloads.
  # Returns major-unit strings keyed by matrix cell; normalize_matrix_payload converts once.
  def smith_matrix_cells_from_legacy_terms(terms, _currency = nil)
    input = terms.to_h.with_indifferent_access
    mapping = {
      first_second_fare: "base_fare:first_second",
      additional_fare: "base_fare:additional",
      single_supplement: "base_fare:single_supplement",
      nccf: "nccf:every_traveler",
      first_second_discount: "discount:first_second",
      additional_discount: "discount:additional",
      taxes_fees: "taxes_fees:every_traveler"
    }
    cells = {}
    mapping.each do |term_key, cell_key|
      next unless input.key?(term_key) || input.key?(term_key.to_s)

      cells[cell_key] = input[term_key]
    end
    cells
  end
end
