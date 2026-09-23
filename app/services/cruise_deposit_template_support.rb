# frozen_string_literal: true

# Creation affordances and typed field projection for Cruise Supplier Deposit Requirements.
# Template choice is not independently persisted.
module CruiseDepositTemplateSupport
  TEMPLATES = {
    "initial_deposit" => {
      label: "Initial deposit",
      default_description: "Initial deposit",
      description_required: false,
      amount_shape: "quantity_times_rate",
      quantity_basis: "capacity_pool_units"
    },
    "final_deposit" => {
      label: "Final deposit",
      default_description: "Final deposit",
      description_required: false,
      amount_shape: "cumulative_target",
      quantity_basis: "capacity_pool_units"
    },
    "other_deposit" => {
      label: "Other deposit",
      default_description: nil,
      description_required: true,
      amount_shape: nil,
      quantity_basis: nil
    }
  }.freeze

  SIMPLE_TIMING_SHAPES = %w[
    fixed_date fixed_local_datetime
    days_before_departure days_after_departure
    hours_before_departure hours_after_departure
  ].freeze

  TYPED_TIMING_SHAPES = (SIMPLE_TIMING_SHAPES + %w[earlier_of]).freeze
  MILESTONE_KIND = "names_assigned_to_supplier"

  TYPED_AMOUNT_SHAPES = %w[
    fixed_amount
    quantity_times_rate
    cumulative_target
  ].freeze

  module_function

  def template_options
    TEMPLATES.map { |key, spec| [ spec.fetch(:label), key ] }
  end

  def template_spec(template_key)
    TEMPLATES.fetch(template_key.to_s) do
      raise AgencyCommand::Error.new("Choose a supported deposit template.", code: :invalid)
    end
  end

  def recognize_template(definition)
    shape = definition.amount_shape.to_s
    basis = definition.quantity_basis.to_s
    description = definition.description.to_s.strip

    case shape
    when "quantity_times_rate"
      return "initial_deposit" if basis == "capacity_pool_units" &&
        definition.rate_minor_units.present? &&
        definition.supplier_deposit_requirement_definition_coverage_links.any? { |link| link.capacity_pool_id.present? }
      return "other_deposit" if basis == "explicit" || (basis == "capacity_pool_units" && definition.rate_minor_units.present?)
    when "cumulative_target"
      if basis == "capacity_pool_units" &&
          definition.rate_minor_units.present? &&
          definition.supplier_deposit_requirement_definition_contributor_links.any?
        return "final_deposit"
      end
    when "fixed_amount"
      return "other_deposit"
    end

    return "other_deposit" if description.present? && TYPED_AMOUNT_SHAPES.include?(shape)

    nil
  end

  def compile_attributes(template_key:, form:, arrangement:, version:, cruise_item:, currency:)
    spec = template_spec(template_key)
    attrs = form.to_h.with_indifferent_access
    description = resolve_description(spec, attrs[:description])
    amount_shape, quantity_basis, amount_fields = compile_amount(spec, attrs, currency)
    rule_shape, precision, rule_parameters = compile_timing(attrs)
    coverage_links = compile_coverage(
      attrs,
      amount_shape: amount_shape,
      quantity_basis: quantity_basis,
      version: version,
      cruise_item: cruise_item
    )
    contributor_definition_ids = compile_contributors(attrs, amount_shape: amount_shape, quantity_basis: quantity_basis)

    {
      attributes: {
        amount_shape:,
        currency: currency.to_s.upcase,
        description:,
        rule_shape:,
        rule_parameters:,
        precision:,
        time_zone: version.departure.time_zone,
        coverage_links:,
        contributor_definition_ids:,
        **amount_fields
      }
    }
  end

  def resolve_description(spec, raw)
    value = raw.to_s.strip.presence || spec[:default_description]
    if spec.fetch(:description_required) && value.blank?
      raise AgencyCommand::Error.new("Enter a name for this deposit.", code: :invalid)
    end
    value
  end

  def compile_amount(spec, attrs, currency)
    amount_shape = attrs[:amount_shape].presence || spec[:amount_shape]
    unless TYPED_AMOUNT_SHAPES.include?(amount_shape.to_s)
      raise AgencyCommand::Error.new("Choose a supported deposit amount shape.", code: :invalid)
    end

    case amount_shape.to_s
    when "fixed_amount"
      minor = parse_money_minor_units(attrs[:fixed_amount], attrs[:fixed_amount_minor_units], currency)
      raise AgencyCommand::Error.new("Enter a fixed deposit amount.", code: :invalid) if minor.nil?

      [ "fixed_amount", nil, { fixed_amount_minor_units: minor } ]
    when "quantity_times_rate"
      basis = attrs[:quantity_basis].presence || spec[:quantity_basis] || "capacity_pool_units"
      unless %w[explicit capacity_pool_units].include?(basis)
        raise AgencyCommand::Error.new("Choose an explicit or cabin-block quantity basis.", code: :invalid)
      end
      rate = parse_money_minor_units(attrs[:rate_amount], attrs[:rate_minor_units], currency)
      raise AgencyCommand::Error.new("Enter a per-unit rate.", code: :invalid) if rate.nil?

      fields = { rate_minor_units: rate, quantity_basis: basis }
      if basis == "explicit"
        quantity = Integer(attrs[:explicit_quantity], exception: false)
        if quantity.nil? || quantity <= 0
          raise AgencyCommand::Error.new("Enter a positive explicit quantity.", code: :invalid)
        end
        fields[:explicit_quantity] = quantity
      end
      [ "quantity_times_rate", basis, fields ]
    when "cumulative_target"
      rate = parse_money_minor_units(attrs[:rate_amount], attrs[:rate_minor_units], currency)
      raise AgencyCommand::Error.new("Enter a cumulative per-unit rate.", code: :invalid) if rate.nil?

      [
        "cumulative_target",
        "capacity_pool_units",
        { rate_minor_units: rate, quantity_basis: "capacity_pool_units" }
      ]
    end
  end

  def parse_money_minor_units(display, minor_units, currency)
    return Integer(minor_units, exception: false) if minor_units.present?

    text = display.to_s.strip
    return nil if text.blank?

    Money.from_amount(BigDecimal(text), currency.to_s.upcase).fractional
  rescue ArgumentError, TypeError, Money::Currency::UnknownCurrency
    raise AgencyCommand::Error.new("Enter a valid money amount.", code: :invalid)
  end

  def compile_timing(attrs)
    rule_shape = attrs[:rule_shape].to_s
    unless TYPED_TIMING_SHAPES.include?(rule_shape)
      raise AgencyCommand::Error.new("Choose a supported deposit timing rule.", code: :invalid)
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
    when "earlier_of"
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
    when "earlier_of"
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
    if shape == "planning_milestone"
      kind = attrs[:"#{prefix}_milestone_kind"].presence || MILESTONE_KIND
      unless kind == MILESTONE_KIND
        raise AgencyCommand::Error.new("Unsupported planning milestone kind.", code: :invalid)
      end
      return {
        "rule_shape" => "planning_milestone",
        "rule_parameters" => { "kind" => kind }
      }
    end

    unless SIMPLE_TIMING_SHAPES.include?(shape)
      raise AgencyCommand::Error.new(
        "Composite timing arms must use a simple rule or names-assigned milestone.",
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

  def compile_coverage(attrs, amount_shape:, quantity_basis:, version:, cruise_item:)
    capacity_based = quantity_basis.to_s == "capacity_pool_units"
    pool_ids = Array(attrs[:capacity_pool_ids]).map(&:presence).compact.map(&:to_s).uniq
    resource_ids = Array(attrs[:supplier_resource_ids]).map(&:presence).compact.map(&:to_s).uniq

    if capacity_based
      if pool_ids.empty? && resource_ids.any?
        pool_ids = resolve_pools_from_resources!(version, resource_ids)
      end
      if pool_ids.empty?
        raise AgencyCommand::Error.new(
          "Select one or more cabin Capacity Pools for this deposit.", code: :invalid
        )
      end
      return normalize_pool_coverage!(version, pool_ids)
    end

    # Arrangement-wide fixed / explicit shapes: exactly one Item coverage link.
    [ { arrangement_item_id: cruise_item.id } ]
  end

  def resolve_pools_from_resources!(version, resource_ids)
    pool_ids = []
    resource_ids.each do |resource_id|
      pools = version.capacity_pool_definitions
        .where(supplier_resource_id: resource_id)
        .order(:id)
        .pluck(:capacity_pool_id)
      if pools.empty?
        raise AgencyCommand::Error.new(
          "Selected cabin category has no Capacity Pool.", code: :invalid
        )
      end
      if pools.size > 1
        raise AgencyCommand::Error.new(
          "Cabin category matches multiple Capacity Pools; select pools explicitly.",
          code: :invalid
        )
      end
      pool_ids << pools.first
    end
    pool_ids.uniq
  end

  def normalize_pool_coverage!(version, pool_ids)
    seen = {}
    pool_ids.filter_map do |pool_id|
      next if seen[pool_id]

      seen[pool_id] = true
      definition = version.capacity_pool_definitions.find_by(capacity_pool_id: pool_id)
      raise AgencyCommand::Error.new("Capacity Pool is not on this Cruise version.", code: :invalid) if definition.nil?

      {
        capacity_pool_id: pool_id,
        arrangement_item_id: definition.arrangement_item_id,
        service_occurrence_id: definition.service_occurrence_id,
        supplier_resource_id: definition.supplier_resource_id
      }
    end
  end

  def compile_contributors(attrs, amount_shape:, quantity_basis:)
    ids = Array(attrs[:contributor_definition_ids]).map(&:presence).compact.map(&:to_s).uniq
    quantity_derived = amount_shape.to_s == "cumulative_target" && quantity_basis.to_s == "capacity_pool_units"
    if quantity_derived && ids.empty?
      raise AgencyCommand::Error.new(
        "Select at least one contributing deposit definition.", code: :invalid
      )
    end
    if !quantity_derived && ids.any?
      raise AgencyCommand::Error.new(
        "Contributors apply only to quantity-derived cumulative deposits.", code: :invalid
      )
    end
    ids
  end

  def timing_sentence(definition)
    timing_sentence_from(
      rule_shape: definition.rule_shape,
      rule_parameters: definition.rule_parameters,
      time_zone: definition.time_zone
    )
  end

  def timing_sentence_from(rule_shape:, rule_parameters:, time_zone:)
    params = (rule_parameters || {}).with_indifferent_access
    case rule_shape.to_s
    when "fixed_date"
      "Due on #{params[:date]} (#{time_zone})"
    when "fixed_local_datetime"
      "Due at #{params[:datetime]} (#{time_zone})"
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
    else
      rule_shape.to_s.humanize
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
    when "planning_milestone"
      if params[:kind].to_s == MILESTONE_KIND
        "names assigned to Supplier"
      else
        "planning milestone"
      end
    else
      shape.presence || "unsupported arm"
    end
  end

  def amount_sentence(definition, currency:)
    case definition.amount_shape
    when "fixed_amount"
      "Fixed #{format_minor(definition.fixed_amount_minor_units, currency)}"
    when "quantity_times_rate"
      rate = format_minor(definition.rate_minor_units, currency)
      if definition.quantity_basis == "capacity_pool_units"
        "#{rate} × cabin Capacity Pool units"
      elsif definition.quantity_basis == "explicit"
        "#{rate} × #{definition.explicit_quantity}"
      else
        "#{rate} × quantity"
      end
    when "cumulative_target"
      if definition.quantity_basis == "capacity_pool_units" && definition.rate_minor_units.present?
        "Cumulative to #{format_minor(definition.rate_minor_units, currency)} × retained cabin units"
      else
        "Cumulative target #{format_minor(definition.target_amount_minor_units, currency)}"
      end
    else
      definition.amount_shape.to_s.humanize
    end
  end

  def format_minor(minor_units, currency)
    return "—" if minor_units.nil?

    Money.new(minor_units, currency.to_s.upcase).format
  end

  def coverage_summary(definition, cruise_shape)
    links = definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id).to_a
    if links.empty?
      return "Coverage missing"
    end

    pool_ids = links.filter_map(&:capacity_pool_id)
    if pool_ids.any?
      labels = pool_ids.map do |pool_id|
        definition_row = cruise_shape.version.capacity_pool_definitions.find_by(capacity_pool_id: pool_id)
        resource = cruise_shape.resources.find { |row| row.id == definition_row&.supplier_resource_id }
        resource_definition = cruise_shape.version.supplier_resource_definitions
          .find_by(supplier_resource_id: resource&.id)
        resource_definition&.supplier_code.presence || resource_definition&.name || "pool"
      end
      return "Cabin pools: #{labels.join(", ")}"
    end

    if links.size == 1 &&
        links.first.arrangement_item_id.present? &&
        links.first.supplier_resource_id.blank? &&
        links.first.capacity_pool_id.blank?
      return "Entire Cruise (#{cruise_shape.item_definition&.name || "Arrangement Item"})"
    end

    "Advanced coverage"
  end

  def project_editor_fields(definition)
    template = recognize_template(definition) || "other_deposit"
    params = (definition.rule_parameters || {}).with_indifferent_access
    coverage_links = definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id)
    contributor_ids = definition.supplier_deposit_requirement_definition_contributor_links
      .order(:position, :id)
      .map(&:contributor_definition_id)

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
      timing_fields[:"#{prefix}_milestone_kind"] = arm_params[:kind]
    end

    {
      template: template,
      description: definition.description,
      amount_shape: definition.amount_shape,
      quantity_basis: definition.quantity_basis,
      fixed_amount_minor_units: definition.fixed_amount_minor_units,
      rate_minor_units: definition.rate_minor_units,
      explicit_quantity: definition.explicit_quantity,
      capacity_pool_ids: coverage_links.filter_map(&:capacity_pool_id),
      supplier_resource_ids: coverage_links.filter_map(&:supplier_resource_id).uniq,
      contributor_definition_ids: contributor_ids,
      timing: timing_fields
    }
  end
end
