# frozen_string_literal: true

# Builder helpers for Cruise Supplier rate schedule composites.
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

  def normalize_rate_terms(terms, currency)
    input = terms.to_h.with_indifferent_access
    CANONICAL_TERM_KEYS.index_with do |key|
      money_minor_or_nil(input[key], currency, CANONICAL_SPECS.fetch(key).fetch(:label).to_s, major_units: true)
    end
  end

  def normalize_commission(commission, currency)
    input = (commission || {}).to_h.with_indifferent_access
    method = (input[:method].presence || "not_provided").to_s
    unless COMMISSION_METHODS.include?(method)
      raise AgencyCommand::Error.new("Choose how expected commission is stated.", code: :invalid)
    end

    case method
    when "not_provided"
      { method: method }
    when "dollar"
      amount = money_minor_or_nil(
        input.key?(:amount) ? input[:amount] : input[:amount_minor_units],
        currency, "Commission amount", major_units: input.key?(:amount)
      )
      raise AgencyCommand::Error.new("Enter the commission amount.", code: :invalid) if amount.nil?
      basis = input[:applies_per].presence || input[:quantity_basis].presence
      basis = "persons" if basis.to_s == "traveler"
      basis = "resource_units" if basis.to_s == "cabin"
      unless DOLLAR_BASES.include?(basis.to_s)
        raise AgencyCommand::Error.new("Choose whether dollar commission applies per traveler or per cabin.", code: :invalid)
      end
      { method: method, amount_minor_units: amount, quantity_basis: basis.to_s }
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
      add_keys = Array(input[:add_bases] || input[:charge_bases]).map(&:to_sym)
      subtract_keys = Array(input[:subtract_bases] || input[:discount_bases]).map(&:to_sym)
      unknown = (add_keys + subtract_keys) - (CHARGE_BASE_KEYS + DISCOUNT_BASE_KEYS)
      if unknown.any?
        raise AgencyCommand::Error.new("Commission bases must be canonical rate components.", code: :invalid)
      end
      if add_keys.empty? && subtract_keys.empty?
        raise AgencyCommand::Error.new("Select at least one commission base.", code: :invalid)
      end
      {
        method: method,
        rate: rate,
        add_bases: add_keys & CHARGE_BASE_KEYS,
        subtract_bases: subtract_keys & DISCOUNT_BASE_KEYS
      }
    end
  end

  def component_attributes_for_term(key, amount_minor_units)
    spec = CANONICAL_SPECS.fetch(key)
    {
      label: spec.fetch(:label),
      economic_role: spec.fetch(:economic_role),
      calculation_kind: "unit_rate",
      amount_minor_units: amount_minor_units,
      quantity_basis: spec.fetch(:quantity_basis),
      occupancy_position_from: spec[:occupancy_position_from],
      occupancy_position_to: spec[:occupancy_position_to],
      percentage_treatment: nil,
      participant_category_id: nil,
      pass_through: false,
      rate: nil,
      minimum_minor_units: nil,
      minimum_quantity: nil
    }
  end

  def commission_component_attributes(commission)
    case commission.fetch(:method)
    when "dollar"
      {
        label: COMMISSION_LABEL,
        economic_role: "expected_commission",
        calculation_kind: "unit_rate",
        amount_minor_units: commission.fetch(:amount_minor_units),
        quantity_basis: commission.fetch(:quantity_basis),
        pass_through: false,
        rate: nil,
        percentage_treatment: nil,
        occupancy_position_from: nil,
        occupancy_position_to: nil,
        participant_category_id: nil,
        minimum_minor_units: nil,
        minimum_quantity: nil
      }
    when "percentage"
      {
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
    end
  end

  def sync_canonical_components!(definition, terms:, commission:)
    components_by_label = definition.supplier_cost_components.lock.index_by(&:label)
    ordered_keys = CANONICAL_TERM_KEYS.select { |key| terms[key].present? || terms[key] == 0 }
    position = 1
    label_to_component = {}

    ordered_keys.each do |key|
      attrs = component_attributes_for_term(key, terms[key])
      label = attrs.fetch(:label)
      existing = components_by_label[label]
      component = if existing
        existing.update!(attrs)
        existing
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      component.update!(position: position) if component.position != position
      label_to_component[label] = component
      components_by_label.delete(label)
      position += 1
    end

    # Remove cleared canonical terms (and their dependent commission links later).
    CANONICAL_TERM_KEYS.each do |key|
      label = CANONICAL_SPECS.fetch(key).fetch(:label)
      next if ordered_keys.include?(key)

      existing = components_by_label.delete(label)
      next unless existing

      destroy_component_and_dependent_bases!(definition, existing)
    end

    existing_commission = components_by_label.delete(COMMISSION_LABEL)
    if commission.fetch(:method) == "not_provided"
      destroy_component_and_dependent_bases!(definition, existing_commission) if existing_commission
    else
      attrs = commission_component_attributes(commission)
      commission_component = if existing_commission
        existing_commission.update!(attrs.merge(position: position))
        existing_commission
      else
        build_supplier_cost_component_already_locked!(
          definition: definition, attributes: attrs, position: position, base_links: []
        )
      end
      commission_component.update!(position: position) if commission_component.position != position
      if commission.fetch(:method) == "percentage"
        links = percentage_base_links(commission, label_to_component)
        replace_base_links!(definition, commission_component, links)
      else
        replace_base_links!(definition, commission_component, [])
      end
      label_to_component[COMMISSION_LABEL] = commission_component
    end

    # Never silently delete noncanonical leftovers — detector marks unsupported.
    leftover_canonical = components_by_label.keys & CruiseSupplierRateSupport.canonical_labels
    leftover_canonical.each do |label|
      destroy_component_and_dependent_bases!(definition, components_by_label[label])
    end

    renumber_components!(definition)
    touch_definition_after_change!(definition)
  end

  def percentage_base_links(commission, label_to_component)
    links = []
    commission.fetch(:add_bases).each do |key|
      component = label_to_component[CANONICAL_SPECS.fetch(key).fetch(:label)]
      raise AgencyCommand::Error.new(
        "Select commission bases that are present on the rate schedule.", code: :invalid
      ) unless component

      links << { base_component_id: component.id, direction: "add", position: links.size + 1 }
    end
    commission.fetch(:subtract_bases).each do |key|
      component = label_to_component[CANONICAL_SPECS.fetch(key).fetch(:label)]
      raise AgencyCommand::Error.new(
        "Select commission bases that are present on the rate schedule.", code: :invalid
      ) unless component

      links << { base_component_id: component.id, direction: "subtract", position: links.size + 1 }
    end
    links
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
end
