# frozen_string_literal: true

module DeadlineDefinitionCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  private

  def lock_deadline_graph!
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

  def ensure_deadline_editable!(departure, arrangement, version, contractor)
    unless version.draft? && (departure.draft? || departure.active?) &&
        !arrangement.abandoned? && contractor.active?
      raise AgencyCommand::Error.new(
        "That Arrangement version cannot edit deadline definitions.", code: :invalid_state
      )
    end
  end

  def normalize_deadline_attributes(version, arrangement, attributes)
    attrs = attributes.to_h.with_indifferent_access
    deadline_type = attrs[:deadline_type].to_s
    kind = attrs[:kind].to_s
    rule_shape = attrs[:rule_shape].to_s
    precision = attrs[:precision].to_s
    cardinality = attrs.fetch(:cardinality, "one_shared").to_s

    unless SupplierDeadlineDefinition::DEADLINE_TYPES.include?(deadline_type) &&
        SupplierDeadlineDefinition::KINDS.include?(kind) &&
        SupplierDeadlineDefinition::RULE_SHAPES.include?(rule_shape) &&
        SupplierDeadlineDefinition::PRECISIONS.include?(precision) &&
        SupplierDeadlineDefinition::CARDINALITIES.include?(cardinality)
      raise AgencyCommand::Error.new("Choose valid deadline definition fields.", code: :invalid)
    end
    if cardinality != "one_shared"
      raise AgencyCommand::Error.new(
        "Only one shared deadline cardinality is supported in M3E.2.", code: :invalid
      )
    end

    other_label = attrs[:other_label].to_s.strip.presence
    if (deadline_type == "other") != other_label.present?
      raise AgencyCommand::Error.new(
        "Enter an other label only for other deadline types.", code: :invalid
      )
    end

    time_zone = normalize_deadline_time_zone(
      attrs[:time_zone].presence || version.departure.time_zone
    )
    rule_parameters = normalize_rule_parameters(rule_shape, precision, attrs[:rule_parameters])
    warning_lead_days = normalize_warning_lead_days(attrs[:warning_lead_days])
    description = normalize_deadline_description(attrs[:description])
    coverage_links = normalize_coverage_links(version, attrs[:coverage_links])
    commitment_lines = normalize_commitment_lines(version, arrangement, kind, attrs[:commitment_lines])

    {
      deadline_type:,
      other_label:,
      kind:,
      rule_shape:,
      rule_parameters:,
      precision:,
      time_zone:,
      cardinality:,
      warning_lead_days:,
      description:,
      coverage_links:,
      commitment_lines:
    }
  end

  def normalize_deadline_time_zone(value)
    zone = value.to_s.strip
    TZInfo::Timezone.get(zone)
    zone
  rescue TZInfo::InvalidTimezoneIdentifier
    raise AgencyCommand::Error.new("Choose a recognized IANA time zone.", code: :invalid)
  end

  def normalize_warning_lead_days(value)
    return nil if value.blank?

    number = Integer(value)
    raise ArgumentError if number.negative?

    number
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new(
      "Warning lead days must be a whole number of zero or more.", code: :invalid
    )
  end

  def normalize_deadline_description(value)
    text = value.to_s.strip.presence
    return text if text.nil? || text.length <= SupplierDeadlineDefinition::DESCRIPTION_LIMIT

    raise AgencyCommand::Error.new("Enter a description of 500 characters or fewer.", code: :invalid)
  end

  def normalize_rule_parameters(rule_shape, precision, raw)
    params = case raw
    when String
      JSON.parse(raw)
    when ActionController::Parameters
      raw.to_unsafe_h
    when Hash
      raw
    else
      {}
    end
    params = params.with_indifferent_access
    reject_milestone_anchors!(params)

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
          unless SupplierDeadlineRuleEvaluator::SIMPLE_SHAPES.include?(arm_shape)
            raise AgencyCommand::Error.new(
              "Composite arm #{index + 1} must use a simple rule shape.", code: :invalid
            )
          end
          {
            "rule_shape" => arm_shape,
            "rule_parameters" => normalize_rule_parameters(
              arm_shape, precision, arm[:rule_parameters] || arm.except(:rule_shape)
            )
          }
        end
      }
    else
      raise AgencyCommand::Error.new("Choose a supported deadline rule shape.", code: :invalid)
    end
  rescue JSON::ParserError
    raise AgencyCommand::Error.new("Deadline rule parameters are invalid.", code: :invalid)
  end

  def reject_milestone_anchors!(params)
    blob = params.to_json
    if blob.match?(/milestone|names_assigned/i)
      raise AgencyCommand::Error.new(
        "Planning-milestone anchors are not supported until M3E.3.", code: :invalid
      )
    end
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

  def normalize_coverage_links(version, raw_links)
    Array(raw_links).map.with_index(1) do |raw, position|
      attrs = raw.to_h.with_indifferent_access
      item_id = parse_optional_uuid(attrs[:arrangement_item_id], "Item")
      occurrence_id = parse_optional_uuid(attrs[:service_occurrence_id], "Occurrence")
      resource_id = parse_optional_uuid(attrs[:supplier_resource_id], "Resource")
      pool_id = parse_optional_uuid(attrs[:capacity_pool_id], "Capacity Pool")
      present = [ item_id, occurrence_id, resource_id, pool_id ].compact
      if present.empty?
        raise AgencyCommand::Error.new("Coverage links require a target.", code: :invalid)
      end

      if pool_id
        definition = version.capacity_pool_definitions.find_by!(
          capacity_pool_id: pool_id
        )
        {
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: definition.service_occurrence_id,
          supplier_resource_id: definition.supplier_resource_id,
          capacity_pool_id: pool_id,
          position:
        }
      elsif resource_id
        definition = version.supplier_resource_definitions.find_by!(
          supplier_resource_id: resource_id
        )
        {
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: nil,
          supplier_resource_id: resource_id,
          capacity_pool_id: nil,
          position:
        }
      elsif occurrence_id
        definition = version.service_occurrence_definitions.find_by!(
          service_occurrence_id: occurrence_id
        )
        {
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: occurrence_id,
          supplier_resource_id: nil,
          capacity_pool_id: nil,
          position:
        }
      else
        version.arrangement_item_definitions.find_by!(arrangement_item_id: item_id)
        {
          arrangement_item_id: item_id,
          service_occurrence_id: nil,
          supplier_resource_id: nil,
          capacity_pool_id: nil,
          position:
        }
      end
    end
  rescue ActiveRecord::RecordNotFound
    raise AgencyCommand::Error.new(
      "Coverage must reference exact-version structure on this draft.", code: :invalid
    )
  end

  def normalize_commitment_lines(version, arrangement, kind, raw_lines)
    lines = Array(raw_lines)
    if kind == "informational" && lines.any?
      raise AgencyCommand::Error.new(
        "Informational deadlines cannot declare commitment lines.", code: :invalid
      )
    end
    lines.map.with_index(1) do |raw, position|
      attrs = raw.to_h.with_indifferent_access
      shape = attrs[:authority_shape].to_s
      unless SupplierDeadlineCommitmentDefinitionLine::AUTHORITY_SHAPES.include?(shape)
        raise AgencyCommand::Error.new("Choose a valid deadline commitment authority.", code: :invalid)
      end
      committed_supplier = resolve_active_supplier!(attrs[:committed_supplier_id], "Committed supplier")
      unless committed_supplier.id == arrangement.contracting_supplier_id ||
          version.arrangement_item_definitions.exists?(default_service_provider_id: committed_supplier.id) ||
          version.service_occurrence_definitions.exists?(service_provider_id: committed_supplier.id)
        raise AgencyCommand::Error.new(
          "The committed supplier is not eligible for this deadline.", code: :invalid
        )
      end
      description = attrs[:description].to_s.strip
      if description.blank? || description.length > SupplierDeadlineCommitmentDefinitionLine::DESCRIPTION_LIMIT
        raise AgencyCommand::Error.new(
          "Enter a commitment description of 500 characters or fewer.", code: :invalid
        )
      end
      base = {
        authority_shape: shape,
        committed_supplier_id: committed_supplier.id,
        description:,
        position:
      }
      case shape
      when "fixed_quantity"
        quantity = Integer(attrs[:fixed_quantity])
        raise ArgumentError unless quantity.positive?
        basis = attrs[:quantity_basis].to_s
        unless SupplierDeadlineCommitmentDefinitionLine::QUANTITY_BASES.include?(basis)
          raise AgencyCommand::Error.new("Choose a valid quantity basis.", code: :invalid)
        end
        base.merge(
          fixed_quantity: quantity, quantity_basis: basis,
          fixed_amount_minor_units: nil, currency: nil,
          supplier_cost_source_id: nil, supplier_cost_definition_id: nil,
          supplier_cost_component_id: nil
        )
      when "fixed_contracted_amount"
        component_id = required_uuid(attrs[:supplier_cost_component_id], "Contracted cost component")
        component = version.supplier_cost_components.includes(
          supplier_cost_definition: :supplier_cost_source
        ).find(component_id)
        definition = component.supplier_cost_definition
        source = definition.supplier_cost_source
        unless definition.contracted? && definition.forecast_ready? &&
            component.supplier_charge? && component.fixed?
          raise AgencyCommand::Error.new(
            "Choose a ready contracted fixed Supplier-charge component.", code: :invalid
          )
        end
        base.merge(
          fixed_quantity: nil, quantity_basis: nil,
          fixed_amount_minor_units: nil, currency: definition.currency,
          supplier_cost_source_id: source.id,
          supplier_cost_definition_id: definition.id,
          supplier_cost_component_id: component.id
        )
      end
    rescue ArgumentError, TypeError
      raise AgencyCommand::Error.new("Fixed quantity must be a positive whole number.", code: :invalid)
    end
  end

  def persist_deadline_children!(definition, coverage_links, commitment_lines)
    coverage_links.each do |attrs|
      definition.supplier_deadline_definition_coverage_links.create!(
        attrs.merge(
          agency_id: definition.agency_id,
          departure_id: definition.departure_id,
          supplier_arrangement_id: definition.supplier_arrangement_id,
          supplier_arrangement_version_id: definition.supplier_arrangement_version_id
        )
      )
    end
    commitment_lines.each do |attrs|
      definition.supplier_deadline_commitment_definition_lines.create!(
        attrs.merge(
          agency_id: definition.agency_id,
          departure_id: definition.departure_id,
          supplier_arrangement_id: definition.supplier_arrangement_id,
          supplier_arrangement_version_id: definition.supplier_arrangement_version_id
        )
      )
    end
  end

  # Update retained children in place so successor `copied_from_id` lineage survives
  # ordinary edits (for example warning lead time only).
  def replace_deadline_children!(definition, coverage_links, commitment_lines)
    existing_coverage = definition.supplier_deadline_definition_coverage_links
      .order(:position, :id).lock.to_a
    coverage_links.each_with_index do |attrs, index|
      if (existing = existing_coverage[index])
        existing.update!(attrs)
      else
        definition.supplier_deadline_definition_coverage_links.create!(
          attrs.merge(child_owner_attrs(definition))
        )
      end
    end
    existing_coverage.drop(coverage_links.size).each(&:destroy!)

    existing_lines = definition.supplier_deadline_commitment_definition_lines
      .order(:position, :id).lock.to_a
    commitment_lines.each_with_index do |attrs, index|
      if (existing = existing_lines[index])
        existing.update!(attrs)
      else
        definition.supplier_deadline_commitment_definition_lines.create!(
          attrs.merge(child_owner_attrs(definition))
        )
      end
    end
    existing_lines.drop(commitment_lines.size).each(&:destroy!)
  end

  def child_owner_attrs(definition)
    {
      agency_id: definition.agency_id,
      departure_id: definition.departure_id,
      supplier_arrangement_id: definition.supplier_arrangement_id,
      supplier_arrangement_version_id: definition.supplier_arrangement_version_id,
      supplier_deadline_definition_id: definition.id
    }
  end

  def deadline_details(definition)
    {
      "supplier_deadline_definition_id" => definition.id,
      "supplier_arrangement_version_id" => definition.supplier_arrangement_version_id,
      "deadline_type" => definition.deadline_type,
      "kind" => definition.kind,
      "rule_shape" => definition.rule_shape
    }
  end
end
