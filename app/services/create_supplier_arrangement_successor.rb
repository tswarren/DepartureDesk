class CreateSupplierArrangementSuccessor < AgencyCommand
  include ArrangementCommandSupport

  COPY_FIELDS_EXCLUDED = %w[
    id supplier_arrangement_version_id copied_from_id created_at updated_at lock_version
  ].freeze

  def initialize(agency:, actor:, arrangement:, arrangement_lock_version:,
    version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure = lock_departure_for!(@arrangement.departure_id)
      arrangement = lock_arrangement_for!(@arrangement)
      predecessor = arrangement.versions.lock.find_by(id: arrangement.governing_version_id)
      payload = {
        supplier_arrangement_id: arrangement.id,
        predecessor_version_id: predecessor&.id,
        arrangement_lock_version: @arrangement_lock_version,
        version_lock_version: @version_lock_version
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: key,
        payload: payload,
        result_class: SupplierArrangementVersion
      ) do
        validate_creation!(departure, arrangement, predecessor)
        ensure_current_lock_version!(arrangement, @arrangement_lock_version)
        ensure_current_lock_version!(predecessor, @version_lock_version)
        lock_predecessor_graph!(predecessor)

        successor = arrangement.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: arrangement.versions.maximum(:version_number).to_i + 1,
          copied_from: predecessor
        )
        copy_graph!(predecessor, successor)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.successor_created",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "predecessor_version_id" => predecessor.id,
            "supplier_arrangement_version_id" => successor.id,
            "version_number" => successor.version_number
          }
        )
        successor
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A successor draft already exists.", code: :conflict)
  end

  private

  def validate_creation!(departure, arrangement, predecessor)
    unless departure.active? && arrangement.active? && predecessor&.activated? &&
        !arrangement.versions.where(status: "draft").exists?
      raise Error.new(
        "Only an active arrangement without a successor draft can create a successor.",
        code: :invalid_state
      )
    end
  end

  def lock_predecessor_graph!(version)
    %i[
      arrangement_item_definitions service_occurrence_definitions
      supplier_resource_definitions capacity_pair_definitions capacity_pool_definitions
      supplier_cost_sources supplier_cost_definitions supplier_cost_components
      supplier_cost_participant_categories supplier_cost_usage_assumptions
      supplier_cost_occupancy_profiles supplier_commitment_trigger_definitions
      supplier_deadline_definitions
    ].each { |association| version.public_send(association).order(:id).lock.load }
    SupplierCostComponentBase.where(supplier_arrangement_version_id: version.id).order(:id).lock.load
    SupplierCostOccupancyProfilePosition.where(
      supplier_arrangement_version_id: version.id
    ).order(:id).lock.load
    SupplierDeadlineDefinitionCoverageLink.where(
      supplier_arrangement_version_id: version.id
    ).order(:id).lock.load
    SupplierDeadlineCommitmentDefinitionLine.where(
      supplier_arrangement_version_id: version.id
    ).order(:id).lock.load
  end

  def copy_graph!(from, to)
    item_definitions = copy_family(from.arrangement_item_definitions, to.arrangement_item_definitions)
    occurrence_definitions = copy_family(
      from.service_occurrence_definitions, to.service_occurrence_definitions
    )
    resource_definitions = copy_family(
      from.supplier_resource_definitions, to.supplier_resource_definitions
    )
    pairs = copy_family(from.capacity_pair_definitions, to.capacity_pair_definitions)
    copy_family(from.capacity_pool_definitions, to.capacity_pool_definitions) do |record|
      { capacity_pair_definition_id: pairs.fetch(record.capacity_pair_definition_id).id }
    end

    categories = copy_family(
      from.supplier_cost_participant_categories, to.supplier_cost_participant_categories
    )
    assumptions = copy_family(
      from.supplier_cost_usage_assumptions, to.supplier_cost_usage_assumptions
    )
    profiles = copy_family(
      from.supplier_cost_occupancy_profiles, to.supplier_cost_occupancy_profiles
    ) do |record|
      { supplier_cost_usage_assumption_id: assumptions.fetch(record.supplier_cost_usage_assumption_id).id }
    end
    copy_profile_positions!(from, to, assumptions, profiles, categories)

    sources = copy_family(from.supplier_cost_sources, to.supplier_cost_sources)
    definitions = copy_family(from.supplier_cost_definitions, to.supplier_cost_definitions) do |record|
      { supplier_cost_source_id: sources.fetch(record.supplier_cost_source_id).id }
    end
    components = copy_family(from.supplier_cost_components, to.supplier_cost_components) do |record|
      {
        supplier_cost_definition_id: definitions.fetch(record.supplier_cost_definition_id).id,
        participant_category_id: record.participant_category_id &&
          categories.fetch(record.participant_category_id).id
      }
    end
    copy_component_bases!(from, to, definitions, components)
    carry_cost_readiness!(definitions)
    copy_triggers!(from, to, sources, definitions, components)
    copy_deadlines!(from, to, sources, definitions, components)

    # These maps are intentionally built even where stable identity means no FK remap.
    # Their construction proves each retained structural definition was copied once.
    [ item_definitions, occurrence_definitions, resource_definitions ]
  end

  def copy_family(source, target)
    source.order(:id).each_with_object({}) do |record, copies|
      overrides = block_given? ? yield(record) : {}
      copies[record.id] = target.create!(
        copy_attributes(record).merge(overrides).merge(copied_from: record)
      )
    end
  end

  def copy_profile_positions!(from, to, assumptions, profiles, categories)
    source = SupplierCostOccupancyProfilePosition.where(
      supplier_arrangement_version_id: from.id
    )
    source.order(:id).each do |record|
      SupplierCostOccupancyProfilePosition.create!(
        copy_attributes(record).merge(
          supplier_arrangement_version: to,
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

  def copy_component_bases!(from, to, definitions, components)
    SupplierCostComponentBase.where(
      supplier_arrangement_version_id: from.id
    ).order(:id).each do |record|
      SupplierCostComponentBase.create!(
        copy_attributes(record).merge(
          supplier_arrangement_version: to,
          supplier_cost_definition_id: definitions.fetch(record.supplier_cost_definition_id).id,
          supplier_cost_component_id: components.fetch(record.supplier_cost_component_id).id,
          base_component_id: components.fetch(record.base_component_id).id,
          copied_from: record
        )
      )
    end
  end

  def carry_cost_readiness!(definitions)
    definitions.each do |source_id, copy|
      next unless copy.forecast_ready?

      fingerprint = SupplierCostDefinitionFingerprint.call(copy)
      copy.update_columns(readiness_fingerprint: fingerprint, updated_at: Time.current)
    end
  end

  def copy_triggers!(from, to, sources, definitions, components)
    copy_family(
      from.supplier_commitment_trigger_definitions,
      to.supplier_commitment_trigger_definitions
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

  def copy_deadlines!(from, to, sources, definitions, components)
    deadline_copies = copy_family(
      from.supplier_deadline_definitions,
      to.supplier_deadline_definitions
    )
    from.supplier_deadline_definition_coverage_links.order(:id).each do |link|
      to.supplier_deadline_definition_coverage_links.create!(
        copy_attributes(link).merge(
          supplier_arrangement_version: to,
          supplier_deadline_definition_id: deadline_copies.fetch(link.supplier_deadline_definition_id).id
        )
      )
    end
    from.supplier_deadline_commitment_definition_lines.order(:id).each do |line|
      to.supplier_deadline_commitment_definition_lines.create!(
        copy_attributes(line).merge(
          supplier_arrangement_version: to,
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

  def remap_optional(map, id)
    id && map.fetch(id).id
  end

  def copy_attributes(record)
    record.attributes.except(*COPY_FIELDS_EXCLUDED).merge(
      "supplier_arrangement_version_id" => nil
    )
  end
end
