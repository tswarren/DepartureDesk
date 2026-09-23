# frozen_string_literal: true

# Definition-scoped, write-free compatibility detector for typed Cruise deposits.
class DetectCruiseDepositRequirementShape
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
    return incompatible(nil, [ "That Deposit Requirement is not part of this Cruise Arrangement." ]) if definition.nil?

    version = definition.supplier_arrangement_version
    if @version && version.id != @version.id
      return incompatible(definition, [ "That Deposit Requirement belongs to a different Arrangement version." ])
    end

    reasons = []
    reasons.concat(amount_reasons(definition))
    reasons.concat(coverage_reasons(definition, version))
    reasons.concat(contributor_reasons(definition, version))
    reasons.concat(timing_reasons(definition))

    template = CruiseDepositTemplateSupport.recognize_template(definition)
    if template.nil? && reasons.empty?
      reasons << "This Deposit Requirement is not a typed Cruise deposit shape."
    end

    if reasons.any?
      return Result.new(
        compatible?: false,
        definition: definition,
        template: template,
        summary: {
          state: "advanced",
          action: "advanced",
          display_label: definition.description.presence || "Deposit requirement",
          amount_shape: definition.amount_shape
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
        display_label: definition.description.presence || CruiseDepositTemplateSupport::TEMPLATES.fetch(template).fetch(:label),
        template: template,
        amount_sentence: CruiseDepositTemplateSupport.amount_sentence(
          definition,
          currency: version.departure.operating_currency
        ),
        timing_sentence: CruiseDepositTemplateSupport.timing_sentence(definition)
      },
      reasons: [],
      projected_fields: CruiseDepositTemplateSupport.project_editor_fields(definition)
    )
  end

  private

  def load_definition(arrangement)
    SupplierDepositRequirementDefinition
      .includes(
        :supplier_deposit_requirement_definition_coverage_links,
        :supplier_deposit_requirement_definition_contributor_links,
        :supplier_deposit_requirement_definition_cost_links
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
        display_label: definition&.description.presence || "Deposit requirement",
        amount_shape: definition&.amount_shape
      },
      reasons: reasons,
      projected_fields: nil
    )
  end

  def amount_reasons(definition)
    reasons = []
    shape = definition.amount_shape.to_s

    if shape == "percentage_of_cost_sources"
      reasons << "Percentage deposits are Advanced for typed Cruise deposits."
      return reasons
    end

    unless CruiseDepositTemplateSupport::TYPED_AMOUNT_SHAPES.include?(shape)
      reasons << "Amount shape #{shape.humanize} is not supported in typed Cruise deposits."
      return reasons
    end

    case shape
    when "quantity_times_rate"
      basis = definition.quantity_basis.to_s
      if %w[traveler_positions resource_units].include?(basis)
        reasons << "Quantity basis #{basis.humanize} is Advanced for typed Cruise deposits."
      elsif !%w[explicit capacity_pool_units].include?(basis)
        reasons << "Quantity basis is incomplete for typed Cruise deposits."
      elsif definition.rate_minor_units.blank?
        reasons << "Rate is required for quantity-times-rate deposits."
      end
    when "cumulative_target"
      if definition.target_amount_minor_units.present? &&
          (definition.quantity_basis != "capacity_pool_units" || definition.rate_minor_units.blank?)
        reasons << "Fixed cumulative targets cannot round-trip in the typed Cruise deposit editor."
      elsif definition.quantity_basis == "capacity_pool_units"
        if definition.rate_minor_units.blank?
          reasons << "Quantity-derived cumulative targets require a rate."
        end
        if definition.supplier_deposit_requirement_definition_contributor_links.empty?
          reasons << "Quantity-derived cumulative targets require contributors."
        end
      else
        reasons << "Cumulative target shape is unsupported for typed Cruise deposits."
      end
    when "fixed_amount"
      if definition.fixed_amount_minor_units.nil?
        reasons << "Fixed amount is incomplete."
      end
    end

    reasons
  end

  def coverage_reasons(definition, version)
    reasons = []
    links = definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id).to_a
    if links.empty?
      reasons << "Deposit coverage is required."
      return reasons
    end

    keys = links.map { |link|
      [ link.arrangement_item_id, link.service_occurrence_id, link.supplier_resource_id, link.capacity_pool_id ]
    }
    if keys.uniq.size != keys.size
      reasons << "Duplicate coverage links are Advanced."
    end

    capacity_based = definition.quantity_basis.to_s == "capacity_pool_units"
    if capacity_based
      links.each do |link|
        if link.capacity_pool_id.blank?
          reasons << "Capacity-based deposits require exact Capacity Pool coverage."
          break
        end
        unless version.capacity_pool_definitions.exists?(capacity_pool_id: link.capacity_pool_id)
          reasons << "Coverage Capacity Pool is not on this Cruise version."
        end
      end
    else
      if links.size != 1
        reasons << "Arrangement-wide deposits require exactly one Item coverage link."
      elsif links.first.capacity_pool_id.present? || links.first.supplier_resource_id.present?
        reasons << "Arrangement-wide deposits must cover the Cruise Item only."
      end
    end

    reasons.uniq
  end

  def contributor_reasons(definition, version)
    reasons = []
    links = definition.supplier_deposit_requirement_definition_contributor_links.order(:position, :id).to_a
    return reasons if links.empty?

    unless definition.amount_shape == "cumulative_target" &&
        definition.quantity_basis == "capacity_pool_units"
      reasons << "Contributors are only valid on quantity-derived cumulative deposits."
      return reasons
    end

    target_pools = definition.supplier_deposit_requirement_definition_coverage_links
      .filter_map(&:capacity_pool_id).map(&:to_s).uniq
    seen = {}
    links.each do |link|
      contributor = version.supplier_deposit_requirement_definitions.find_by(id: link.contributor_definition_id)
      if contributor.nil?
        reasons << "Contributor definition is missing."
        next
      end
      if seen[contributor.id]
        reasons << "Duplicate contributors are Advanced."
      end
      seen[contributor.id] = true

      if contributor.id == definition.id
        reasons << "A deposit cannot contribute to itself."
      end
      if contributor.amount_shape != "quantity_times_rate" ||
          contributor.quantity_basis != "capacity_pool_units"
        reasons << "Contributors must be prior capacity-pool quantity deposits."
      end
      contributor_pools = contributor.supplier_deposit_requirement_definition_coverage_links
        .filter_map(&:capacity_pool_id).map(&:to_s).uniq
      unless (contributor_pools & target_pools).any?
        reasons << "Contributor coverage must overlap the cumulative deposit pools."
      end
      if contributor.position.to_i >= definition.position.to_i
        reasons << "Contributors must be earlier definitions on this version."
      end
    end

    reasons.uniq
  end

  def timing_reasons(definition)
    reasons = []
    shape = definition.rule_shape.to_s
    params = (definition.rule_parameters || {}).with_indifferent_access

    unless CruiseDepositTemplateSupport::TYPED_TIMING_SHAPES.include?(shape)
      reasons << "Timing rule #{shape.humanize} is not supported in typed Cruise deposits."
      return reasons
    end

    if shape == "earlier_of"
      arms = Array(params[:arms])
      unless arms.size == 2
        reasons << "Earlier-of timing requires exactly two arms."
        return reasons
      end

      milestone_count = 0
      arms.each_with_index do |arm, index|
        arm = arm.with_indifferent_access
        arm_shape = arm[:rule_shape].to_s
        if arm_shape == "planning_milestone"
          milestone_count += 1
          kind = arm.dig(:rule_parameters, "kind").to_s
          if kind != CruiseDepositTemplateSupport::MILESTONE_KIND
            reasons << "Unsupported planning milestone kind on arm #{index + 1}."
          end
        elsif !CruiseDepositTemplateSupport::SIMPLE_TIMING_SHAPES.include?(arm_shape)
          reasons << "Composite arm #{index + 1} must use a simple rule or names-assigned milestone."
        end
      end
      if milestone_count > 1
        reasons << "Typed deposits allow at most one names-assigned milestone arm."
      end
    end

    reasons
  end
end
