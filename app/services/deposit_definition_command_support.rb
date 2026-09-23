# frozen_string_literal: true

module DepositDefinitionCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  private

  def lock_deposit_graph!
    arrangement = @agency.supplier_arrangements.find(
      @version.is_a?(SupplierArrangementVersion) ? @version.supplier_arrangement_id : @arrangement.id
    )
    departure = lock_departure_for!(arrangement.departure_id)
    arrangement = lock_arrangement_for!(arrangement)
    version_id = @version.is_a?(SupplierArrangementVersion) ? @version.id : @version
    version = arrangement.versions.lock.find(version_id)
    contractor = lock_suppliers_in_uuid_order!(arrangement.contracting_supplier_id).first
    [ departure, arrangement, version, contractor ]
  end

  def ensure_deposit_editable!(departure, arrangement, version, contractor)
    unless version.draft? && (departure.draft? || departure.active?) &&
        !arrangement.abandoned? && contractor.active?
      raise AgencyCommand::Error.new(
        "That Arrangement version cannot edit deposit requirement definitions.", code: :invalid_state
      )
    end
  end

  def normalize_deposit_attributes(version, arrangement, attributes)
    attrs = attributes.to_h.with_indifferent_access
    amount_shape = attrs[:amount_shape].to_s
    rule_shape = attrs[:rule_shape].to_s
    precision = attrs.fetch(:precision, "date_only").to_s
    currency = attrs[:currency].to_s.strip.upcase

    unless SupplierDepositRequirementDefinition::AMOUNT_SHAPES.include?(amount_shape) &&
        SupplierDepositRequirementDefinition::RULE_SHAPES.include?(rule_shape) &&
        SupplierDepositRequirementDefinition::PRECISIONS.include?(precision)
      raise AgencyCommand::Error.new("Choose valid deposit definition fields.", code: :invalid)
    end
    unless currency.match?(/\A[A-Z]{3}\z/)
      raise AgencyCommand::Error.new("Enter a three-letter currency code.", code: :invalid)
    end

    time_zone = normalize_deposit_time_zone(attrs[:time_zone].presence || version.departure.time_zone)
    amount_fields = normalize_amount_fields(amount_shape, attrs)
    rule_parameters = normalize_deposit_rule_parameters(rule_shape, precision, attrs[:rule_parameters])
    description = normalize_deposit_description(attrs[:description])
    coverage_links = normalize_deposit_coverage_links(version, attrs[:coverage_links])
    cost_links = normalize_deposit_cost_links(version, amount_shape, attrs[:cost_links])
    contributor_links = normalize_deposit_contributor_links(
      version, amount_shape, amount_fields, attrs[:contributor_definition_ids] || attrs[:contributor_links]
    )

    amount_fields.merge(
      amount_shape:,
      currency:,
      rule_shape:,
      rule_parameters:,
      precision:,
      time_zone:,
      description:,
      coverage_links:,
      cost_links:,
      contributor_links:
    )
  end

  def normalize_amount_fields(amount_shape, attrs)
    blank = {
      fixed_amount_minor_units: nil, rate_minor_units: nil, quantity_basis: nil,
      explicit_quantity: nil, percentage: nil, rounding_scope: nil, target_amount_minor_units: nil
    }
    case amount_shape
    when "fixed_amount"
      amount = required_nonnegative_minor_units(attrs[:fixed_amount_minor_units], "Fixed amount")
      blank.merge(fixed_amount_minor_units: amount)
    when "quantity_times_rate"
      rate = required_nonnegative_minor_units(attrs[:rate_minor_units], "Rate")
      basis = attrs[:quantity_basis].to_s
      unless SupplierDepositRequirementDefinition::QUANTITY_BASES.include?(basis)
        raise AgencyCommand::Error.new("Choose a quantity basis.", code: :invalid)
      end
      explicit = nil
      if basis == "explicit"
        explicit = Integer(attrs[:explicit_quantity])
        raise ArgumentError unless explicit.positive?
      end
      blank.merge(rate_minor_units: rate, quantity_basis: basis, explicit_quantity: explicit)
    when "percentage_of_cost_sources"
      percentage = BigDecimal(attrs[:percentage].to_s)
      raise ArgumentError unless percentage.positive?

      scope = attrs[:rounding_scope].to_s
      unless SupplierDepositRequirementDefinition::ROUNDING_SCOPES.include?(scope)
        raise AgencyCommand::Error.new("Choose aggregate or per-source rounding.", code: :invalid)
      end
      blank.merge(percentage:, rounding_scope: scope)
    when "cumulative_target"
      if attrs[:quantity_basis].to_s == "capacity_pool_units" || attrs[:rate_minor_units].present?
        rate = required_nonnegative_minor_units(attrs[:rate_minor_units], "Cumulative rate")
        basis = attrs[:quantity_basis].to_s
        unless basis == "capacity_pool_units"
          raise AgencyCommand::Error.new(
            "Quantity-derived cumulative targets require capacity_pool_units.", code: :invalid
          )
        end
        blank.merge(rate_minor_units: rate, quantity_basis: basis)
      else
        target = required_nonnegative_minor_units(attrs[:target_amount_minor_units], "Target amount")
        blank.merge(target_amount_minor_units: target)
      end
    else
      raise AgencyCommand::Error.new("Choose a supported deposit amount shape.", code: :invalid)
    end
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Enter valid deposit amount fields.", code: :invalid)
  end

  def normalize_deposit_contributor_links(version, amount_shape, amount_fields, raw)
    links = Array(raw).filter_map do |entry|
      case entry
      when Hash, ActionController::Parameters
        entry = entry.to_h.with_indifferent_access
        entry[:contributor_definition_id] || entry[:id]
      else
        entry
      end
    end
    quantity_derived = amount_shape == "cumulative_target" &&
      amount_fields[:quantity_basis] == "capacity_pool_units"
    if quantity_derived && links.empty?
      raise AgencyCommand::Error.new(
        "Quantity-derived cumulative targets require at least one contributor.", code: :invalid
      )
    end
    if amount_shape != "cumulative_target" && links.any?
      raise AgencyCommand::Error.new(
        "Contributor links are only used for cumulative targets.", code: :invalid
      )
    end
    if amount_shape == "cumulative_target" && amount_fields[:target_amount_minor_units].present? && links.any?
      raise AgencyCommand::Error.new(
        "Fixed cumulative targets do not use contributor links.", code: :invalid
      )
    end

    links.map.with_index(1) do |raw_id, position|
      contributor_id = parse_required_uuid(raw_id, "Contributor definition")
      contributor = version.supplier_deposit_requirement_definitions.find_by(id: contributor_id)
      if contributor.nil?
        raise AgencyCommand::Error.new("Contributor definition is not on this version.", code: :invalid)
      end
      { contributor_definition_id: contributor_id, position: }
    end
  end

  def required_nonnegative_minor_units(value, label)
    number = Integer(value)
    raise ArgumentError if number.negative?

    number
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} must be a whole number of zero or more.", code: :invalid)
  end

  def normalize_deposit_time_zone(value)
    zone = value.to_s.strip
    TZInfo::Timezone.get(zone)
    zone
  rescue TZInfo::InvalidTimezoneIdentifier
    raise AgencyCommand::Error.new("Choose a recognized IANA time zone.", code: :invalid)
  end

  def normalize_deposit_description(value)
    text = value.to_s.strip.presence
    return text if text.nil? || text.length <= SupplierDepositRequirementDefinition::DESCRIPTION_LIMIT

    raise AgencyCommand::Error.new("Enter a description of 500 characters or fewer.", code: :invalid)
  end

  def normalize_deposit_rule_parameters(rule_shape, precision, raw)
    params = case raw
    when String then JSON.parse(raw)
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else {}
    end
    params = params.with_indifferent_access

    case rule_shape
    when "fixed_date"
      raise AgencyCommand::Error.new("Fixed date rules require date precision.", code: :invalid) unless
        precision == "date_only"
      { "date" => required_iso_date(params[:date], "Fixed date") }
    when "fixed_local_datetime"
      raise AgencyCommand::Error.new(
        "Fixed local datetime rules require local date/time precision.", code: :invalid
      ) unless precision == "local_date_time"
      { "datetime" => required_local_datetime(params[:datetime], "Fixed local datetime") }
    when "days_before_departure", "days_after_departure"
      raise AgencyCommand::Error.new("Day offset rules require date precision.", code: :invalid) unless
        precision == "date_only"
      { "days" => required_days(params[:days], rule_shape) }
    when "hours_before_departure", "hours_after_departure"
      raise AgencyCommand::Error.new(
        "Hour offset rules require local date/time precision.", code: :invalid
      ) unless precision == "local_date_time"
      { "hours" => required_hours(params[:hours], rule_shape) }
    when "earlier_of", "later_of"
      arms = Array(params[:arms])
      unless arms.size == 2
        raise AgencyCommand::Error.new(
          "#{rule_shape.humanize} requires exactly two arms.", code: :invalid
        )
      end
      {
        "arms" => arms.map.with_index do |arm, index|
          arm = arm.with_indifferent_access
          arm_shape = arm[:rule_shape].to_s
          allowed = SupplierDeadlineRuleEvaluator::SIMPLE_SHAPES +
            [ SupplierDeadlineRuleEvaluator::MILESTONE_SHAPE ]
          unless allowed.include?(arm_shape)
            raise AgencyCommand::Error.new(
              "Composite arm #{index + 1} must use a supported rule shape.", code: :invalid
            )
          end
          if arm_shape == SupplierDeadlineRuleEvaluator::MILESTONE_SHAPE
            kind = arm.dig(:rule_parameters, :kind) || arm[:kind]
            kind = kind.to_s
            unless SupplierPlanningMilestoneOccurrence::KINDS.include?(kind)
              raise AgencyCommand::Error.new(
                "Choose a supported planning milestone kind.", code: :invalid
              )
            end
            { "rule_shape" => arm_shape, "rule_parameters" => { "kind" => kind } }
          else
            {
              "rule_shape" => arm_shape,
              "rule_parameters" => normalize_deposit_rule_parameters(
                arm_shape, precision, arm[:rule_parameters] || arm.except(:rule_shape)
              )
            }
          end
        end
      }
    else
      raise AgencyCommand::Error.new("Choose a supported deposit due-rule shape.", code: :invalid)
    end
  rescue JSON::ParserError
    raise AgencyCommand::Error.new("Deposit due-rule parameters are invalid.", code: :invalid)
  end

  def required_iso_date(value, label)
    Date.iso8601(value.to_s).iso8601
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("#{label} must be an ISO date.", code: :invalid)
  end

  def required_local_datetime(value, label)
    text = value.to_s.strip
    raise AgencyCommand::Error.new("#{label} can't be blank.", code: :invalid) if text.blank?

    text
  end

  def required_days(value, rule_shape)
    number = Integer(value)
    if rule_shape == "days_before_departure"
      raise ArgumentError unless number.positive?
    elsif number.negative?
      raise ArgumentError
    end
    number
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Enter a valid day offset.", code: :invalid)
  end

  def required_hours(value, rule_shape)
    number = Integer(value)
    if rule_shape == "hours_before_departure"
      raise ArgumentError unless number.positive?
    elsif number.negative?
      raise ArgumentError
    end
    number
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Enter a valid hour offset.", code: :invalid)
  end

  def normalize_deposit_coverage_links(version, raw_links)
    Array(raw_links).map.with_index(1) do |raw, position|
      attrs = raw.to_h.with_indifferent_access
      item_id = parse_optional_uuid(attrs[:arrangement_item_id], "Item")
      occurrence_id = parse_optional_uuid(attrs[:service_occurrence_id], "Occurrence")
      resource_id = parse_optional_uuid(attrs[:supplier_resource_id], "Resource")
      pool_id = parse_optional_uuid(attrs[:capacity_pool_id], "Capacity Pool")
      present = [ item_id, occurrence_id, resource_id, pool_id ].compact
      if present.empty?
        raise AgencyCommand::Error.new("Each coverage link needs a target.", code: :invalid)
      end
      validate_coverage_structure!(version, item_id, occurrence_id, resource_id, pool_id)
      {
        arrangement_item_id: item_id,
        service_occurrence_id: occurrence_id,
        supplier_resource_id: resource_id,
        capacity_pool_id: pool_id,
        position:
      }
    end
  end

  def validate_coverage_structure!(version, item_id, occurrence_id, resource_id, pool_id)
    if item_id.present?
      unless version.arrangement_item_definitions.exists?(arrangement_item_id: item_id)
        raise AgencyCommand::Error.new("Coverage item is not on this version.", code: :invalid)
      end
    end
    if occurrence_id.present?
      unless version.service_occurrence_definitions.exists?(
        service_occurrence_id: occurrence_id, arrangement_item_id: item_id
      )
        raise AgencyCommand::Error.new("Coverage occurrence is not on this version.", code: :invalid)
      end
    end
    if resource_id.present?
      unless version.supplier_resource_definitions.exists?(
        supplier_resource_id: resource_id, arrangement_item_id: item_id
      )
        raise AgencyCommand::Error.new("Coverage resource is not on this version.", code: :invalid)
      end
    end
    return if pool_id.blank?

    pool = CapacityPool.find_by(
      id: pool_id, agency_id: version.agency_id, supplier_arrangement_id: version.supplier_arrangement_id
    )
    raise AgencyCommand::Error.new("Coverage pool is not on this Arrangement.", code: :invalid) if pool.nil?
  end

  def normalize_deposit_cost_links(version, amount_shape, raw_links)
    links = Array(raw_links)
    if amount_shape == "percentage_of_cost_sources" && links.empty?
      raise AgencyCommand::Error.new(
        "Percentage deposits require at least one cost source.", code: :invalid
      )
    end
    if amount_shape != "percentage_of_cost_sources" && links.any?
      raise AgencyCommand::Error.new(
        "Cost links are only used for percentage deposits.", code: :invalid
      )
    end

    links.map.with_index(1) do |raw, position|
      attrs = raw.to_h.with_indifferent_access
      source_id = parse_required_uuid(attrs[:supplier_cost_source_id], "Cost source")
      source = version.supplier_cost_sources.find_by(id: source_id)
      raise AgencyCommand::Error.new("Cost source is not on this version.", code: :invalid) if source.nil?

      definition_id = parse_optional_uuid(attrs[:supplier_cost_definition_id], "Cost definition")
      component_id = parse_optional_uuid(attrs[:supplier_cost_component_id], "Cost component")
      if definition_id.present?
        definition = version.supplier_cost_definitions.find_by(
          id: definition_id, supplier_cost_source_id: source_id
        )
        raise AgencyCommand::Error.new("Cost definition is not on this source.", code: :invalid) if definition.nil?
      end
      if component_id.present?
        raise AgencyCommand::Error.new("Cost component requires a definition.", code: :invalid) if definition_id.blank?

        component = version.supplier_cost_components.find_by(
          id: component_id, supplier_cost_definition_id: definition_id
        )
        raise AgencyCommand::Error.new("Cost component is not on this definition.", code: :invalid) if component.nil?
      end
      {
        supplier_cost_source_id: source_id,
        supplier_cost_definition_id: definition_id,
        supplier_cost_component_id: component_id,
        position:
      }
    end
  end

  def parse_required_uuid(value, label)
    parse_optional_uuid(value, label).tap do |id|
      raise AgencyCommand::Error.new("#{label} is required.", code: :invalid) if id.blank?
    end
  end

  def persist_deposit_children!(definition, coverage_links, cost_links, contributor_links = [])
    coverage_links.each do |attrs|
      definition.supplier_deposit_requirement_definition_coverage_links.create!(
        attrs.merge(
          agency_id: definition.agency_id,
          departure_id: definition.departure_id,
          supplier_arrangement_id: definition.supplier_arrangement_id,
          supplier_arrangement_version_id: definition.supplier_arrangement_version_id
        )
      )
    end
    cost_links.each do |attrs|
      definition.supplier_deposit_requirement_definition_cost_links.create!(
        attrs.merge(
          agency_id: definition.agency_id,
          departure_id: definition.departure_id,
          supplier_arrangement_id: definition.supplier_arrangement_id,
          supplier_arrangement_version_id: definition.supplier_arrangement_version_id
        )
      )
    end
    Array(contributor_links).each do |attrs|
      definition.supplier_deposit_requirement_definition_contributor_links.create!(
        attrs.merge(
          agency_id: definition.agency_id,
          departure_id: definition.departure_id,
          supplier_arrangement_id: definition.supplier_arrangement_id,
          supplier_arrangement_version_id: definition.supplier_arrangement_version_id
        )
      )
    end
  end

  def replace_deposit_children!(definition, coverage_links, cost_links, contributor_links = [])
    definition.supplier_deposit_requirement_definition_coverage_links.delete_all
    definition.supplier_deposit_requirement_definition_cost_links.delete_all
    definition.supplier_deposit_requirement_definition_contributor_links.delete_all
    persist_deposit_children!(definition, coverage_links, cost_links, contributor_links)
  end

  def deposit_details(definition)
    {
      "supplier_deposit_requirement_definition_id" => definition.id,
      "amount_shape" => definition.amount_shape,
      "currency" => definition.currency,
      "rule_shape" => definition.rule_shape
    }
  end
end
