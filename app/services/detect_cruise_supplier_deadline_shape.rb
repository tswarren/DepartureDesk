# frozen_string_literal: true

class DetectCruiseSupplierDeadlineShape
  Result = Data.define(
    :compatible?,
    :definition,
    :template,
    :summary,
    :reasons,
    :projected_fields
  )

  def initialize(agency:, arrangement:, definition:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @definition = definition
    @version = version
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    definition = load_definition(arrangement)
    return incompatible(nil, [ "That Deadline is not part of this Cruise Arrangement." ]) if definition.nil?

    version = definition.supplier_arrangement_version
    if @version && version.id != @version.id
      return incompatible(definition, [ "That Deadline belongs to a different Arrangement version." ])
    end

    reasons = []
    if definition.cardinality != "one_shared"
      reasons << "Cruise deadlines support one shared cardinality only (per_source is Advanced)."
    end

    template = CruiseDeadlineTemplateSupport.recognize_template(definition)
    if template.nil?
      reasons << "This Deadline type/kind is not a typed Cruise template."
    else
      reasons.concat(template_kind_reasons(template, definition))
    end

    reasons.concat(timing_reasons(definition))
    reasons.concat(coverage_reasons(definition, version))
    reasons.concat(commitment_reasons(template, definition, arrangement))

    if reasons.any?
      return Result.new(
        compatible?: false,
        definition: definition,
        template: template,
        summary: {
          state: "advanced",
          action: "advanced",
          display_label: definition.display_label,
          kind: definition.kind
        },
        reasons: reasons,
        projected_fields: nil
      )
    end

    Result.new(
      compatible?: true,
      definition: definition,
      template: template,
      summary: {
        state: "typed",
        action: "edit",
        display_label: definition.display_label,
        kind: definition.kind,
        template: template,
        timing_sentence: CruiseDeadlineTemplateSupport.timing_sentence(definition)
      },
      reasons: [],
      projected_fields: CruiseDeadlineTemplateSupport.project_editor_fields(definition)
    )
  end

  private

  def load_definition(arrangement)
    SupplierDeadlineDefinition
      .includes(
        :supplier_deadline_definition_coverage_links,
        :supplier_deadline_commitment_definition_lines
      )
      .joins(:supplier_arrangement_version)
      .where(supplier_arrangement_versions: { supplier_arrangement_id: arrangement.id })
      .find_by(id: @definition.id)
  end

  def incompatible(definition, reasons)
    Result.new(
      compatible?: false,
      definition: definition,
      template: nil,
      summary: {
        state: "advanced",
        action: "advanced",
        display_label: definition&.display_label,
        kind: definition&.kind
      },
      reasons: reasons,
      projected_fields: nil
    )
  end

  def template_kind_reasons(template, definition)
    spec = CruiseDeadlineTemplateSupport::TEMPLATES.fetch(template)
    reasons = []
    if spec.fetch(:kind_fixed) && definition.kind != spec.fetch(:default_kind)
      reasons << "Template #{spec.fetch(:label)} requires kind #{spec.fetch(:default_kind)}."
    end
    if template == "final_payment" && definition.other_label.to_s.strip.casecmp("final payment") != 0
      reasons << "Final payment template requires the Final payment label."
    end
    reasons
  end

  def timing_reasons(definition)
    reasons = []
    shape = definition.rule_shape.to_s
    params = (definition.rule_parameters || {}).with_indifferent_access

    blob = params.to_json
    if blob.match?(/milestone|names_assigned/i)
      reasons << "Planning-milestone anchors are Advanced for Supplier Deadlines."
    end

    unless CruiseDeadlineTemplateSupport::TYPED_TIMING_SHAPES.include?(shape)
      reasons << "Timing rule #{shape.humanize} is not supported in typed Cruise deadlines."
      return reasons
    end

    if CruiseDeadlineTemplateSupport::COMPOSITE_TIMING_SHAPES.include?(shape)
      arms = Array(params[:arms])
      unless arms.size == 2
        reasons << "Composite timing requires exactly two simple arms."
        return reasons
      end
      arms.each_with_index do |arm, index|
        arm = arm.with_indifferent_access
        arm_shape = arm[:rule_shape].to_s
        unless CruiseDeadlineTemplateSupport::SIMPLE_TIMING_SHAPES.include?(arm_shape)
          reasons << "Composite arm #{index + 1} must use a simple Departure-relative or fixed rule."
        end
        arm_blob = (arm[:rule_parameters] || {}).to_json
        if arm_blob.match?(/milestone|names_assigned/i)
          reasons << "Planning-milestone arms are Advanced for Supplier Deadlines."
        end
      end
    end

    expected_precision = case shape
    when "fixed_date", "days_before_departure", "days_after_departure"
      "date_only"
    when "fixed_local_datetime", "hours_before_departure", "hours_after_departure"
      "local_date_time"
    when "earlier_of", "later_of"
      arm_shapes = Array(params[:arms]).map { |arm| arm.with_indifferent_access[:rule_shape].to_s }
      if arm_shapes.any? { |arm_shape| arm_shape.start_with?("hours_") || arm_shape == "fixed_local_datetime" }
        "local_date_time"
      else
        "date_only"
      end
    end

    if expected_precision && definition.precision != expected_precision
      reasons << "Timing precision does not match the typed rule shape."
    end

    reasons
  end

  def coverage_reasons(definition, version)
    links = definition.supplier_deadline_definition_coverage_links.order(:position, :id).to_a
    cruise_item = version.arrangement_item_definitions.order(:position, :id).first&.arrangement_item
    reasons = []

    if links.empty?
      reasons << "Typed Cruise deadlines require Arrangement-item coverage (empty coverage is Advanced)."
      return reasons
    end

    projected = CruiseDeadlineTemplateSupport.project_coverage_fields(links)
    if projected[:scope] == "unsupported" || links.size > 1
      reasons << "Coverage is ambiguous or uses a shape the typed selector cannot reconstruct."
      return reasons
    end

    case projected[:scope]
    when "arrangement"
      unless links.one? && links.first.arrangement_item_id == cruise_item&.id
        reasons << "Arrangement-wide coverage must target the Cruise Arrangement Item."
      end
    when "resource"
      resource_id = projected[:supplier_resource_id]
      unless version.supplier_resource_definitions.exists?(supplier_resource_id: resource_id)
        reasons << "Coverage Resource is not part of this Cruise version."
      end
    when "capacity_pool"
      pool_id = projected[:capacity_pool_id]
      unless version.capacity_pool_definitions.exists?(capacity_pool_id: pool_id)
        reasons << "Coverage Capacity Pool is not part of this Cruise version."
      end
    end

    reasons
  end

  def commitment_reasons(template, definition, arrangement)
    lines = definition.supplier_deadline_commitment_definition_lines.order(:position, :id).to_a
    reasons = []

    if definition.informational?
      reasons << "Informational deadlines must have no commitment lines." if lines.any?
      return reasons
    end

    if lines.size != 1
      reasons << "Actionable typed deadlines require exactly one commitment line."
      return reasons
    end

    line = lines.first
    unless CruiseDeadlineTemplateSupport.typed_commitment_line?(line, arrangement: arrangement)
      reasons << "Commitment authority must be fixed quantity 1 resource unit for the contracting Supplier."
    end

    if template == "rooming_list"
      reasons << "Rooming list deadlines are informational and cannot carry commitment lines."
    end

    reasons
  end
end
