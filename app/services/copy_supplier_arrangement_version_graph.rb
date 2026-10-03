# frozen_string_literal: true

# Copies one exact Arrangement version graph onto another version.
# Callers own the transaction, the new version row, and confirmation.
class CopySupplierArrangementVersionGraph
  COPY_FIELDS_EXCLUDED = %w[
    id supplier_arrangement_version_id copied_from_id created_at updated_at lock_version
  ].freeze

  def self.lock!(version)
    new(version, version).lock!
  end

  def self.copy!(from:, to:)
    new(from, to).copy!
  end

  def initialize(from, to)
    @from = from
    @to = to
  end

  def lock!
    %i[
      arrangement_item_definitions service_occurrence_definitions
      supplier_resource_definitions capacity_pair_definitions capacity_pool_definitions
      supplier_cost_sources supplier_cost_definitions supplier_cost_components
      supplier_cost_participant_categories supplier_cost_usage_assumptions
      supplier_cost_occupancy_profiles supplier_commitment_trigger_definitions
      supplier_deadline_definitions
      supplier_deposit_requirement_definitions
      supplier_arrangement_commercial_benefit_definitions
      supplier_arrangement_cruise_term_definitions
      supplier_agreement_references
      supplier_agreement_reference_absences
      supplier_amount_due_definitions
      supplier_amount_due_contributors
      supplier_operating_threshold_definitions
      supplier_payment_requirement_definitions
    ].each { |association| @from.public_send(association).order(:id).lock.load }
    SupplierCostComponentBase.where(supplier_arrangement_version_id: @from.id).order(:id).lock.load
    SupplierCostOccupancyProfilePosition.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).lock.load
    SupplierDeadlineDefinitionCoverageLink.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).lock.load
    SupplierDeadlineCommitmentDefinitionLine.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).lock.load
    SupplierDepositRequirementDefinitionCoverageLink.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).lock.load
    SupplierDepositRequirementDefinitionCostLink.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).lock.load
  end

  def copy!
    item_definitions = copy_family(@from.arrangement_item_definitions, @to.arrangement_item_definitions)
    occurrence_definitions = copy_family(
      @from.service_occurrence_definitions, @to.service_occurrence_definitions
    )
    resource_definitions = copy_family(
      @from.supplier_resource_definitions, @to.supplier_resource_definitions
    )
    pairs = copy_family(@from.capacity_pair_definitions, @to.capacity_pair_definitions)
    copy_family(@from.capacity_pool_definitions, @to.capacity_pool_definitions) do |record|
      { capacity_pair_definition_id: pairs.fetch(record.capacity_pair_definition_id).id }
    end

    categories = copy_family(
      @from.supplier_cost_participant_categories, @to.supplier_cost_participant_categories
    )
    assumptions = copy_family(
      @from.supplier_cost_usage_assumptions, @to.supplier_cost_usage_assumptions
    )
    profiles = copy_family(
      @from.supplier_cost_occupancy_profiles, @to.supplier_cost_occupancy_profiles
    ) do |record|
      { supplier_cost_usage_assumption_id: assumptions.fetch(record.supplier_cost_usage_assumption_id).id }
    end
    copy_profile_positions!(assumptions, profiles, categories)

    sources = copy_family(@from.supplier_cost_sources, @to.supplier_cost_sources)
    definitions = copy_family(@from.supplier_cost_definitions, @to.supplier_cost_definitions) do |record|
      { supplier_cost_source_id: sources.fetch(record.supplier_cost_source_id).id }
    end
    components = copy_family(@from.supplier_cost_components, @to.supplier_cost_components) do |record|
      {
        supplier_cost_definition_id: definitions.fetch(record.supplier_cost_definition_id).id,
        participant_category_id: record.participant_category_id &&
          categories.fetch(record.participant_category_id).id
      }
    end
    copy_component_bases!(definitions, components)
    carry_cost_readiness!(definitions)
    copy_triggers!(sources, definitions, components)
    copy_deadlines!(sources, definitions, components)
    copy_deposits!(sources, definitions, components)
    copy_amount_dues!(components)
    copy_activity_terms!(components)
    copy_family(@from.supplier_agreement_references, @to.supplier_agreement_references)
    copy_family(@from.supplier_agreement_reference_absences, @to.supplier_agreement_reference_absences)
    copy_family(
      @from.supplier_arrangement_commercial_benefit_definitions,
      @to.supplier_arrangement_commercial_benefit_definitions
    )
    copy_family(
      @from.supplier_arrangement_cruise_term_definitions,
      @to.supplier_arrangement_cruise_term_definitions
    )

    [ item_definitions, occurrence_definitions, resource_definitions ]
  end

  private

  def copy_family(source, target)
    source.order(:id).each_with_object({}) do |record, copies|
      overrides = block_given? ? yield(record) : {}
      copies[record.id] = target.create!(
        copy_attributes(record).merge(overrides).merge(copied_from: record)
      )
    end
  end

  def copy_profile_positions!(assumptions, profiles, categories)
    SupplierCostOccupancyProfilePosition.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).each do |record|
      SupplierCostOccupancyProfilePosition.create!(
        copy_attributes(record).merge(
          supplier_arrangement_version: @to,
          supplier_cost_usage_assumption_id: assumptions.fetch(
            record.supplier_cost_usage_assumption_id
          ).id,
          supplier_cost_occupancy_profile_id: profiles.fetch(
            record.supplier_cost_occupancy_profile_id
          ).id,
          participant_category_id: categories.fetch(record.participant_category_id).id,
          copied_from: record
        )
      )
    end
  end

  def copy_component_bases!(definitions, components)
    SupplierCostComponentBase.where(
      supplier_arrangement_version_id: @from.id
    ).order(:id).each do |record|
      SupplierCostComponentBase.create!(
        copy_attributes(record).merge(
          supplier_arrangement_version: @to,
          supplier_cost_definition_id: definitions.fetch(record.supplier_cost_definition_id).id,
          supplier_cost_component_id: components.fetch(record.supplier_cost_component_id).id,
          base_component_id: components.fetch(record.base_component_id).id,
          copied_from: record
        )
      )
    end
  end

  def carry_cost_readiness!(definitions)
    definitions.each do |_source_id, copy|
      next unless copy.forecast_ready?

      fingerprint = SupplierCostDefinitionFingerprint.call(copy)
      copy.update_columns(readiness_fingerprint: fingerprint, updated_at: Time.current)
    end
  end

  def copy_triggers!(sources, definitions, components)
    copy_family(
      @from.supplier_commitment_trigger_definitions,
      @to.supplier_commitment_trigger_definitions
    ) do |record|
      {
        supplier_cost_source_id: remap_optional(sources, record.supplier_cost_source_id),
        supplier_cost_definition_id: remap_optional(
          definitions, record.supplier_cost_definition_id
        ),
        supplier_cost_component_id: remap_optional(components, record.supplier_cost_component_id)
      }
    end
  end

  def copy_deadlines!(sources, definitions, components)
    deadline_copies = copy_family(
      @from.supplier_deadline_definitions,
      @to.supplier_deadline_definitions
    )
    @from.supplier_deadline_definition_coverage_links.order(:id).each do |link|
      @to.supplier_deadline_definition_coverage_links.create!(
        copy_attributes(link).merge(
          supplier_arrangement_version: @to,
          supplier_deadline_definition_id: deadline_copies.fetch(link.supplier_deadline_definition_id).id
        )
      )
    end
    @from.supplier_deadline_commitment_definition_lines.order(:id).each do |line|
      @to.supplier_deadline_commitment_definition_lines.create!(
        copy_attributes(line).merge(
          supplier_arrangement_version: @to,
          supplier_deadline_definition_id: deadline_copies.fetch(line.supplier_deadline_definition_id).id,
          supplier_cost_source_id: remap_optional(sources, line.supplier_cost_source_id),
          supplier_cost_definition_id: remap_optional(definitions, line.supplier_cost_definition_id),
          supplier_cost_component_id: remap_optional(components, line.supplier_cost_component_id),
          copied_from: line
        )
      )
    end
    deadline_copies
  end

  def copy_amount_dues!(components)
    definitions = copy_family(@from.supplier_amount_due_definitions, @to.supplier_amount_due_definitions)
    @from.supplier_amount_due_contributors.order(:position, :id).each do |contributor|
      @to.supplier_amount_due_contributors.create!(
        copy_attributes(contributor).merge(
          supplier_arrangement_version: @to,
          supplier_amount_due_definition_id: definitions.fetch(contributor.supplier_amount_due_definition_id).id,
          supplier_cost_component_id: components.fetch(contributor.supplier_cost_component_id).id,
          copied_from: contributor
        )
      )
    end
  end

  def copy_activity_terms!(components)
    copy_family(
      @from.supplier_operating_threshold_definitions,
      @to.supplier_operating_threshold_definitions
    )
    copy_family(
      @from.supplier_payment_requirement_definitions,
      @to.supplier_payment_requirement_definitions
    ) do |record|
      { supplier_cost_component_id: components.fetch(record.supplier_cost_component_id).id }
    end
  end

  def copy_deposits!(sources, definitions, components)
    deposit_copies = copy_family(
      @from.supplier_deposit_requirement_definitions,
      @to.supplier_deposit_requirement_definitions
    )
    @from.supplier_deposit_requirement_definition_coverage_links.order(:id).each do |link|
      @to.supplier_deposit_requirement_definition_coverage_links.create!(
        copy_attributes(link).merge(
          supplier_arrangement_version: @to,
          supplier_deposit_requirement_definition_id:
            deposit_copies.fetch(link.supplier_deposit_requirement_definition_id).id
        )
      )
    end
    @from.supplier_deposit_requirement_definition_cost_links.order(:id).each do |link|
      @to.supplier_deposit_requirement_definition_cost_links.create!(
        copy_attributes(link).merge(
          supplier_arrangement_version: @to,
          supplier_deposit_requirement_definition_id:
            deposit_copies.fetch(link.supplier_deposit_requirement_definition_id).id,
          supplier_cost_source_id: remap_optional(sources, link.supplier_cost_source_id),
          supplier_cost_definition_id: remap_optional(definitions, link.supplier_cost_definition_id),
          supplier_cost_component_id: remap_optional(components, link.supplier_cost_component_id)
        )
      )
    end
    @from.supplier_deposit_requirement_definition_contributor_links.order(:id).each do |link|
      @to.supplier_deposit_requirement_definition_contributor_links.create!(
        copy_attributes(link).merge(
          supplier_arrangement_version: @to,
          supplier_deposit_requirement_definition_id:
            deposit_copies.fetch(link.supplier_deposit_requirement_definition_id).id,
          contributor_definition_id:
            deposit_copies.fetch(link.contributor_definition_id).id
        )
      )
    end
    deposit_copies
  end

  def remap_optional(map, id)
    id && map.fetch(id).id
  end

  def copy_attributes(record)
    record.attributes.except(*COPY_FIELDS_EXCLUDED).merge(
      "supplier_arrangement_version_id" => nil
    )
  end
end
