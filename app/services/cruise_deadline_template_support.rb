# frozen_string_literal: true

module CruiseDeadlineTemplateSupport
  TEMPLATES = {
    "option_or_release" => {
      label: "Option/release decision",
      deadline_type: "option_or_release_date",
      default_kind: "actionable",
      kind_fixed: true,
      default_other_label: nil,
      default_commitment_description:
        "Review retained cabins and release any unretained block by the option date"
    },
    "final_payment" => {
      label: "Final payment",
      deadline_type: "other",
      default_kind: "actionable",
      kind_fixed: false,
      default_other_label: "Final payment",
      default_commitment_description:
        "Record Supplier final-payment evidence (not a Client Payment record)"
    },
    "rooming_list" => {
      label: "Rooming list",
      deadline_type: "rooming_list_due",
      default_kind: "informational",
      kind_fixed: true,
      default_other_label: nil,
      default_commitment_description: nil
    },
    "other" => {
      label: "Other Supplier deadline",
      deadline_type: "other",
      default_kind: "informational",
      kind_fixed: false,
      default_other_label: nil,
      default_commitment_description:
        "Complete the required Supplier deadline action or evidence"
    }
  }.freeze

  SIMPLE_TIMING_SHAPES = %w[
    fixed_date fixed_local_datetime
    days_before_departure days_after_departure
    hours_before_departure hours_after_departure
  ].freeze

  COMPOSITE_TIMING_SHAPES = %w[earlier_of later_of].freeze
  TYPED_TIMING_SHAPES = (SIMPLE_TIMING_SHAPES + COMPOSITE_TIMING_SHAPES).freeze

  TYPED_ACTIONABLE_AUTHORITY = {
    authority_shape: "fixed_quantity",
    fixed_quantity: 1,
    quantity_basis: "resource_units"
  }.freeze

  module_function

  def template_options
    TEMPLATES.map { |key, spec| [ spec.fetch(:label), key ] }
  end

  def template_spec(template_key)
    TEMPLATES.fetch(template_key.to_s) do
      raise AgencyCommand::Error.new("Choose a supported deadline template.", code: :invalid)
    end
  end

  def recognize_template(definition)
    type = definition.deadline_type.to_s
    kind = definition.kind.to_s
    other_label = definition.other_label.to_s.strip

    case type
    when "option_or_release_date"
      return "option_or_release" if kind == "actionable"
    when "rooming_list_due"
      return "rooming_list" if kind == "informational"
    when "other"
      if other_label.casecmp("final payment").zero?
        return "final_payment" if %w[actionable informational].include?(kind)
      elsif other_label.present?
        return "other" if %w[actionable informational].include?(kind)
      end
    end

    nil
  end

  def compile_attributes(
    template_key:,
    kind:,
    other_label:,
    description:,
    warning_lead_days:,
    timing:,
    coverage:,
    arrangement:,
    version:,
    cruise_item:
  )
    spec = template_spec(template_key)
    resolved_kind = resolve_kind(spec, kind)
    resolved_label = resolve_other_label(spec, other_label)
    rule_shape, precision, rule_parameters = compile_timing(timing)
    coverage_links = compile_coverage(coverage, version: version, cruise_item: cruise_item)
    commitment_lines = compile_commitment_lines(
      spec: spec,
      kind: resolved_kind,
      description: description,
      arrangement: arrangement
    )

    {
      deadline_type: spec.fetch(:deadline_type),
      other_label: resolved_label,
      kind: resolved_kind,
      rule_shape:,
      rule_parameters:,
      precision:,
      time_zone: version.departure.time_zone,
      cardinality: "one_shared",
      warning_lead_days:,
      description: description.to_s.strip.presence,
      coverage_links:,
      commitment_lines:
    }
  end

  def resolve_kind(spec, kind)
    return spec.fetch(:default_kind) if spec.fetch(:kind_fixed)

    value = kind.to_s.presence || spec.fetch(:default_kind)
    unless SupplierDeadlineDefinition::KINDS.include?(value)
      raise AgencyCommand::Error.new("Choose actionable or informational.", code: :invalid)
    end
    value
  end

  def resolve_other_label(spec, other_label)
    type = spec.fetch(:deadline_type)
    return nil unless type == "other"

    label = other_label.to_s.strip.presence || spec[:default_other_label]
    if label.blank?
      raise AgencyCommand::Error.new("Enter a label for this deadline.", code: :invalid)
    end
    label
  end

  def compile_timing(timing)
    attrs = timing.to_h.with_indifferent_access
    rule_shape = attrs[:rule_shape].to_s
    unless TYPED_TIMING_SHAPES.include?(rule_shape)
      raise AgencyCommand::Error.new("Choose a supported timing rule.", code: :invalid)
    end

    precision = precision_for(rule_shape, attrs)
    parameters = case rule_shape
    when "fixed_date"
      { "date" => attrs[:fixed_date].presence || attrs.dig(:rule_parameters, "date") }
    when "fixed_local_datetime"
      { "datetime" => attrs[:fixed_datetime].presence || attrs.dig(:rule_parameters, "datetime") }
    when "days_before_departure", "days_after_departure"
      { "days" => attrs[:offset_days].presence || attrs.dig(:rule_parameters, "days") }
    when "hours_before_departure", "hours_after_departure"
      { "hours" => attrs[:offset_hours].presence || attrs.dig(:rule_parameters, "hours") }
    when "earlier_of", "later_of"
      {
        "arms" => [
          compile_arm(attrs, "arm1"),
          compile_arm(attrs, "arm2")
        ]
      }
    end

    [ rule_shape, precision, parameters ]
  end

  def precision_for(rule_shape, attrs)
    case rule_shape
    when "fixed_date", "days_before_departure", "days_after_departure"
      "date_only"
    when "fixed_local_datetime", "hours_before_departure", "hours_after_departure"
      "local_date_time"
    when "earlier_of", "later_of"
      arm_shapes = [ attrs[:arm1_rule_shape], attrs[:arm2_rule_shape] ].map(&:to_s)
      if arm_shapes.any? { |shape| shape.start_with?("hours_") || shape == "fixed_local_datetime" }
        "local_date_time"
      else
        "date_only"
      end
    else
      attrs[:precision].presence || "date_only"
    end
  end

  def compile_arm(attrs, prefix)
    shape = attrs[:"#{prefix}_rule_shape"].to_s
    unless SIMPLE_TIMING_SHAPES.include?(shape)
      raise AgencyCommand::Error.new(
        "Composite timing arms must use a simple Departure-relative or fixed rule.",
        code: :invalid
      )
    end

    params = case shape
    when "fixed_date"
      { "date" => attrs[:"#{prefix}_fixed_date"] }
    when "fixed_local_datetime"
      { "datetime" => attrs[:"#{prefix}_fixed_datetime"] }
    when "days_before_departure", "days_after_departure"
      { "days" => attrs[:"#{prefix}_offset_days"] }
    when "hours_before_departure", "hours_after_departure"
      { "hours" => attrs[:"#{prefix}_offset_hours"] }
    else
      {}
    end
    { "rule_shape" => shape, "rule_parameters" => params }
  end

  def compile_coverage(coverage, version:, cruise_item:)
    attrs = coverage.to_h.with_indifferent_access
    scope = attrs[:scope].to_s.presence || "arrangement"

    links = case scope
    when "arrangement", ""
      [ { arrangement_item_id: cruise_item.id } ]
    when "resource"
      resource_id = attrs[:supplier_resource_id].presence
      raise AgencyCommand::Error.new("Choose a cabin category for coverage.", code: :invalid) if resource_id.blank?

      [ { supplier_resource_id: resource_id } ]
    when "capacity_pool"
      pool_id = attrs[:capacity_pool_id].presence
      raise AgencyCommand::Error.new("Choose a Capacity Pool for coverage.", code: :invalid) if pool_id.blank?

      [ { capacity_pool_id: pool_id } ]
    else
      raise AgencyCommand::Error.new("Choose a supported coverage scope.", code: :invalid)
    end

    normalize_coverage_links!(links)
  end

  def normalize_coverage_links!(links)
    seen = {}
    links.filter_map do |link|
      attrs = link.to_h.with_indifferent_access
      key = [
        attrs[:arrangement_item_id],
        attrs[:service_occurrence_id],
        attrs[:supplier_resource_id],
        attrs[:capacity_pool_id]
      ].map(&:to_s)
      if seen[key]
        raise AgencyCommand::Error.new(
          "Coverage targets must be unique for this deadline.", code: :invalid
        )
      end
      seen[key] = true
      attrs
    end
  end

  def compile_commitment_lines(spec:, kind:, description:, arrangement:)
    return [] if kind == "informational"

    text = description.to_s.strip.presence || spec[:default_commitment_description]
    if text.blank?
      raise AgencyCommand::Error.new(
        "Enter a description of the required Supplier action or evidence.", code: :invalid
      )
    end

    [
      TYPED_ACTIONABLE_AUTHORITY.merge(
        committed_supplier_id: arrangement.contracting_supplier_id,
        description: text
      )
    ]
  end

  def timing_sentence(definition)
    params = (definition.rule_parameters || {}).with_indifferent_access
    case definition.rule_shape
    when "fixed_date"
      "Due on #{params[:date]} (#{definition.time_zone})"
    when "fixed_local_datetime"
      "Due at #{params[:datetime]} (#{definition.time_zone})"
    when "days_before_departure"
      "#{params[:days]} day#{"s" unless params[:days].to_i == 1} before Departure"
    when "days_after_departure"
      "#{params[:days]} day#{"s" unless params[:days].to_i == 1} after Departure"
    when "hours_before_departure"
      "#{params[:hours]} hour#{"s" unless params[:hours].to_i == 1} before Departure"
    when "hours_after_departure"
      "#{params[:hours]} hour#{"s" unless params[:hours].to_i == 1} after Departure"
    when "earlier_of"
      "Earlier of #{arm_sentence(params.dig(:arms, 0))} or #{arm_sentence(params.dig(:arms, 1))}"
    when "later_of"
      "Later of #{arm_sentence(params.dig(:arms, 0))} or #{arm_sentence(params.dig(:arms, 1))}"
    else
      definition.rule_shape.to_s.humanize
    end
  end

  def arm_sentence(arm)
    arm = (arm || {}).with_indifferent_access
    shape = arm[:rule_shape].to_s
    params = (arm[:rule_parameters] || {}).with_indifferent_access
    case shape
    when "fixed_date" then params[:date].to_s
    when "fixed_local_datetime" then params[:datetime].to_s
    when "days_before_departure" then "#{params[:days]} days before Departure"
    when "days_after_departure" then "#{params[:days]} days after Departure"
    when "hours_before_departure" then "#{params[:hours]} hours before Departure"
    when "hours_after_departure" then "#{params[:hours]} hours after Departure"
    else shape.presence || "unsupported arm"
    end
  end

  def project_editor_fields(definition)
    template = recognize_template(definition)
    params = (definition.rule_parameters || {}).with_indifferent_access
    coverage = definition.supplier_deadline_definition_coverage_links.order(:position, :id).to_a
    coverage_fields = project_coverage_fields(coverage)
    timing_fields = {
      rule_shape: definition.rule_shape,
      precision: definition.precision,
      fixed_date: params[:date],
      fixed_datetime: params[:datetime],
      offset_days: params[:days],
      offset_hours: params[:hours]
    }
    arms = Array(params[:arms])
    2.times do |index|
      arm = (arms[index] || {}).with_indifferent_access
      arm_params = (arm[:rule_parameters] || {}).with_indifferent_access
      prefix = "arm#{index + 1}"
      timing_fields[:"#{prefix}_rule_shape"] = arm[:rule_shape]
      timing_fields[:"#{prefix}_fixed_date"] = arm_params[:date]
      timing_fields[:"#{prefix}_fixed_datetime"] = arm_params[:datetime]
      timing_fields[:"#{prefix}_offset_days"] = arm_params[:days]
      timing_fields[:"#{prefix}_offset_hours"] = arm_params[:hours]
    end

    {
      template: template,
      kind: definition.kind,
      other_label: definition.other_label,
      description: definition.description,
      warning_lead_days: definition.warning_lead_days,
      timing: timing_fields,
      coverage: coverage_fields
    }
  end

  def project_coverage_fields(coverage_links)
    if coverage_links.empty?
      return { scope: "arrangement", supplier_resource_id: nil, capacity_pool_id: nil }
    end

    link = coverage_links.first
    if link.capacity_pool_id.present?
      { scope: "capacity_pool", supplier_resource_id: nil, capacity_pool_id: link.capacity_pool_id }
    elsif link.supplier_resource_id.present? && link.service_occurrence_id.blank?
      {
        scope: "resource",
        supplier_resource_id: link.supplier_resource_id,
        capacity_pool_id: nil
      }
    elsif link.arrangement_item_id.present? &&
        link.service_occurrence_id.blank? &&
        link.supplier_resource_id.blank? &&
        link.capacity_pool_id.blank?
      { scope: "arrangement", supplier_resource_id: nil, capacity_pool_id: nil }
    else
      { scope: "unsupported", supplier_resource_id: nil, capacity_pool_id: nil }
    end
  end

  def typed_commitment_line?(line, arrangement:)
    line.authority_shape == "fixed_quantity" &&
      line.fixed_quantity == 1 &&
      line.quantity_basis == "resource_units" &&
      line.committed_supplier_id == arrangement.contracting_supplier_id &&
      line.supplier_cost_component_id.nil? &&
      line.description.present?
  end
end
