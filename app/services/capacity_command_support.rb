module CapacityCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  CAPACITY_LABEL_LIMIT = CapacityPoolDefinition::LABEL_LIMIT
  CAPACITY_NOTES_LIMIT = CapacityPoolDefinition::NOTES_LIMIT
  CAPACITY_UNIT_LABEL_LIMIT = CapacityPoolDefinition::UNIT_LABEL_LIMIT
  CAPACITY_EVIDENCE_NOTE_LIMIT = CapacityPoolDefinition::EVIDENCE_REFERENCE_NOTE_LIMIT
  CAPACITY_EVIDENCE_EXTERNAL_LIMIT = CapacityPoolDefinition::EVIDENCE_EXTERNAL_REFERENCE_LIMIT
  CAPACITY_OVERRIDE_REASON_LIMIT = CapacityPoolDefinition::OVERRIDE_REASON_LIMIT

  private

  def ensure_capacity_ordinary_edit!(departure, arrangement, version, contractor)
    ensure_draft_graph!(arrangement, version)
    return if ordinary_planning_state?(departure, contractor)

    raise AgencyCommand::Error.new(recovery_message, code: :invalid_state)
  end

  def ensure_capacity_recovery_edit!(departure, arrangement, version)
    ensure_draft_graph!(arrangement, version)
    return if departure.draft? || departure.active? || departure.departed?

    raise AgencyCommand::Error.new("That departure cannot be edited.", code: :invalid_state)
  end

  def capacity_recovery_only?(departure, contractor, *suppliers)
    return true if departure.departed?
    return true if contractor&.inactive?

    suppliers.compact.any?(&:inactive?)
  end

  def ensure_capacity_management_transition!(departure, contractor, definition, capacity_management)
    return unless capacity_recovery_only?(departure, contractor, item_effective_provider(definition, contractor))
    return if definition.capacity_management == "managed" && capacity_management == "unmanaged"

    raise AgencyCommand::Error.new(recovery_message, code: :invalid_state)
  end

  def item_has_capacity_structure?(version, item)
    version.capacity_pair_definitions.where(arrangement_item: item).exists? ||
      version.capacity_pool_definitions.where(arrangement_item: item).exists?
  end

  def ensure_no_item_capacity_structure!(version, item)
    return unless item_has_capacity_structure?(version, item)

    raise AgencyCommand::Error.new("Remove pair classifications and capacity pools before marking the item unmanaged.", code: :invalid_state)
  end

  def ensure_managed_item!(definition)
    return if definition&.capacity_management == "managed"

    raise AgencyCommand::Error.new("Mark the item as managed before configuring capacity.", code: :invalid_state)
  end

  def ensure_pooled_pair!(pair)
    return if pair&.pooled?

    raise AgencyCommand::Error.new("Classify the pair as pooled before adding a capacity pool.", code: :invalid_state)
  end

  def ensure_pair_has_no_pool_definitions!(pair)
    return unless pair.capacity_pool_definitions.exists?

    raise AgencyCommand::Error.new("Remove capacity pools before changing this pair.", code: :invalid_state)
  end

  def ensure_occurrence_accepts_capacity!(occurrence)
    return unless occurrence.cancelled?

    raise AgencyCommand::Error.new("Cancelled occurrences cannot receive new capacity configuration.", code: :invalid_state)
  end

  def lock_pair_for!(version, pair)
    version.capacity_pair_definitions.lock.find(pair.id)
  end

  def lock_pair_by_members!(version, occurrence, resource)
    version.capacity_pair_definitions.lock.find_by(
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id
    )
  end

  def lock_pool_for!(arrangement, pool)
    arrangement.capacity_pools.lock.find(pool.id)
  end

  def lock_pool_definition_for!(version, definition)
    version.capacity_pool_definitions.lock.find(definition.id)
  end

  def lock_current_pool_definitions_for!(version, pair)
    version.capacity_pool_definitions
      .where(capacity_pair_definition: pair)
      .order(:position, :id)
      .lock
      .to_a
  end

  def lock_exact_capacity_graph!(version, item, occurrence, resource)
    item_definition = version.arrangement_item_definitions.lock.find_by!(arrangement_item: item)
    occurrence = lock_occurrence_for!(item, occurrence)
    resource = lock_resource_for!(item, resource)
    occurrence_definition = version.service_occurrence_definitions.lock.find_by!(
      arrangement_item: item,
      service_occurrence: occurrence
    )
    version.supplier_resource_definitions.lock.find_by!(
      arrangement_item: item,
      supplier_resource: resource
    )

    [ item_definition, occurrence, occurrence_definition, resource ]
  end

  def effective_provider_for!(arrangement, item_definition, occurrence_definition)
    provider = occurrence_definition.service_provider ||
      item_definition.default_service_provider ||
      arrangement.contracting_supplier
    @agency.suppliers.lock.find(provider.id)
  end

  def item_effective_provider(definition, contractor)
    definition.default_service_provider || contractor
  end

  def pool_provider_mismatch?(pool_definition)
    version = pool_definition.supplier_arrangement_version
    item_definition = version.arrangement_item_definitions.find_by(arrangement_item: pool_definition.arrangement_item)
    occurrence_definition = version.service_occurrence_definitions.find_by(
      arrangement_item: pool_definition.arrangement_item,
      service_occurrence: pool_definition.service_occurrence
    )
    return true if item_definition.nil? || occurrence_definition.nil?

    provider = occurrence_definition.service_provider ||
      item_definition.default_service_provider ||
      pool_definition.supplier_arrangement.contracting_supplier
    pool_definition.capacity_pool.supplying_supplier_id != provider.id
  end

  def pool_zone_mismatch?(pool_definition)
    occurrence_definition = pool_definition.supplier_arrangement_version.service_occurrence_definitions.find_by(
      arrangement_item: pool_definition.arrangement_item,
      service_occurrence: pool_definition.service_occurrence
    )
    return true if occurrence_definition.nil?

    pool_definition.capacity_pool.effective_time_zone != occurrence_definition.time_zone
  end

  def normalize_pool_definition_attributes(attrs, pool: nil, siblings: [], generate_label: true)
    attrs = attrs.to_h.with_indifferent_access
    inventory_mode = normalize_inventory_mode(attrs[:inventory_mode] || pool&.inventory_mode)
    normalized = {
      label: normalize_capacity_label(attrs[:label]),
      notes: normalize_capacity_notes(attrs[:notes]),
      unit_label: normalize_unit_label(attrs[:unit_label]),
      proposed_opening_quantity: normalize_proposed_quantity(attrs[:proposed_opening_quantity], inventory_mode)
    }.merge(normalize_evidence_or_override(attrs))

    normalized[:label] ||= generated_capacity_label(
      inventory_mode: inventory_mode,
      quantity: normalized[:proposed_opening_quantity],
      unit_label: normalized[:unit_label],
      siblings: siblings
    ) if generate_label
    normalized[:normalized_label] = normalized[:label].downcase.strip if normalized[:label]
    normalized
  end

  def normalize_pool_definition_update_attributes(attrs, definition)
    attrs = attrs.to_h.with_indifferent_access
    pool = definition.capacity_pool
    inventory_mode = pool.inventory_mode
    label = attrs.key?(:label) ? normalize_capacity_label(attrs[:label]) : definition.label
    label ||= definition.label
    {
      label: label,
      normalized_label: label.downcase.strip,
      notes: attrs.key?(:notes) ? normalize_capacity_notes(attrs[:notes]) : definition.notes,
      unit_label: attrs.key?(:unit_label) ? normalize_unit_label(attrs[:unit_label]) : definition.unit_label,
      proposed_opening_quantity: attrs.key?(:proposed_opening_quantity) ?
        normalize_proposed_quantity(attrs[:proposed_opening_quantity], inventory_mode) :
        definition.proposed_opening_quantity
    }.merge(normalize_existing_evidence_or_override(attrs, definition))
  end

  def normalize_inventory_mode(value)
    mode = value.to_s.strip.presence
    return mode if CapacityPool::INVENTORY_MODES.include?(mode)

    raise AgencyCommand::Error.new("Choose a valid inventory mode.", code: :invalid)
  end

  def normalize_measurement_basis(value)
    basis = value.to_s.strip.presence
    return basis if CapacityPool::MEASUREMENT_BASES.include?(basis)

    raise AgencyCommand::Error.new("Choose a valid measurement basis.", code: :invalid)
  end

  def normalize_capacity_label(value)
    label = value.to_s.strip.presence
    return nil if label.blank?
    if label.length > CAPACITY_LABEL_LIMIT
      raise AgencyCommand::Error.new("Label must be #{CAPACITY_LABEL_LIMIT} characters or fewer.", code: :invalid)
    end

    label
  end

  def normalize_capacity_notes(value)
    notes = value.to_s.strip.presence
    if notes && notes.length > CAPACITY_NOTES_LIMIT
      raise AgencyCommand::Error.new("Notes must be #{CAPACITY_NOTES_LIMIT} characters or fewer.", code: :invalid)
    end

    notes
  end

  def normalize_unit_label(value)
    label = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a unit label.", code: :invalid) if label.blank?
    if label.length > CAPACITY_UNIT_LABEL_LIMIT
      raise AgencyCommand::Error.new("Unit label must be #{CAPACITY_UNIT_LABEL_LIMIT} characters or fewer.", code: :invalid)
    end

    label
  end

  def normalize_proposed_quantity(value, inventory_mode)
    if %w[on_request externally_managed].include?(inventory_mode)
      raise AgencyCommand::Error.new("Nonnumeric pools cannot include a proposed opening quantity.", code: :invalid) if value.present?

      return nil
    end

    return nil if value.blank?

    quantity = value.is_a?(Integer) ? value : Integer(value, 10)
    quantity.tap do |parsed|
      raise AgencyCommand::Error.new("Proposed opening quantity must be greater than zero.", code: :invalid) unless parsed.positive?
    end
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Proposed opening quantity must be a whole number.", code: :invalid)
  end

  def normalize_evidence_or_override(attrs)
    override = ActiveModel::Type::Boolean.new.cast(attrs[:override])
    if override
      ensure_directory_actor!(@actor, @agency, :override_supplier_planning_terms)
      reason = attrs[:override_reason].to_s.strip
      raise AgencyCommand::Error.new("Enter an override reason.", code: :invalid) if reason.blank?
      if reason.length > CAPACITY_OVERRIDE_REASON_LIMIT
        raise AgencyCommand::Error.new("Override reason must be #{CAPACITY_OVERRIDE_REASON_LIMIT} characters or fewer.", code: :invalid)
      end

      return {
        evidence_kind: nil,
        evidence_on: nil,
        evidence_reference_note: nil,
        evidence_external_reference: nil,
        override: true,
        override_reason: reason
      }
    end

    {
      evidence_kind: normalize_evidence_kind(attrs[:evidence_kind]),
      evidence_on: parse_date(attrs[:evidence_on], "Evidence date"),
      evidence_reference_note: normalize_evidence_reference_note(attrs[:evidence_reference_note]),
      evidence_external_reference: normalize_evidence_external_reference(attrs[:evidence_external_reference]),
      override: false,
      override_reason: nil
    }
  end

  def normalize_existing_evidence_or_override(attrs, definition)
    evidence_keys = %i[evidence_kind evidence_on evidence_reference_note evidence_external_reference override override_reason]
    return {
      evidence_kind: definition.evidence_kind,
      evidence_on: definition.evidence_on,
      evidence_reference_note: definition.evidence_reference_note,
      evidence_external_reference: definition.evidence_external_reference,
      override: definition.override?,
      override_reason: definition.override_reason
    } unless evidence_keys.any? { |key| attrs.key?(key) }

    normalize_evidence_or_override(attrs)
  end

  def normalize_evidence_kind(value)
    kind = value.to_s.strip.presence
    return nil if kind.blank?
    return kind if CapacityPoolDefinition::EVIDENCE_KINDS.include?(kind)

    raise AgencyCommand::Error.new("Choose a valid evidence kind.", code: :invalid)
  end

  def normalize_evidence_reference_note(value)
    note = value.to_s.strip.presence
    if note && note.length > CAPACITY_EVIDENCE_NOTE_LIMIT
      raise AgencyCommand::Error.new("Evidence note must be #{CAPACITY_EVIDENCE_NOTE_LIMIT} characters or fewer.", code: :invalid)
    end

    note
  end

  def normalize_evidence_external_reference(value)
    reference = value.to_s.strip.presence
    if reference && reference.length > CAPACITY_EVIDENCE_EXTERNAL_LIMIT
      raise AgencyCommand::Error.new("External reference must be #{CAPACITY_EVIDENCE_EXTERNAL_LIMIT} characters or fewer.", code: :invalid)
    end

    reference
  end

  def generated_capacity_label(inventory_mode:, quantity:, unit_label:, siblings:)
    base = [ inventory_mode.tr("_", " ") ]
    base << quantity if quantity.present?
    base << unit_label
    stem = base.join(" ").squish
    used = siblings.map(&:normalized_label)
    ordinal = 1
    loop do
      label = ordinal == 1 ? stem : "#{stem} #{ordinal}"
      return label if label.length <= CAPACITY_LABEL_LIMIT && !used.include?(label.downcase)

      ordinal += 1
    end
  end

  def next_pool_position(version, pair)
    version.capacity_pool_definitions.where(capacity_pair_definition: pair).maximum(:position).to_i + 1
  end

  def capacity_definition_changed_fields(definition, attrs)
    attrs.keys.select { |field| definition.saved_change_to_attribute?(field) }.map(&:to_s)
  end

  def normalized_capacity_pool_id_list(values)
    Array(values).map { |value| parse_optional_uuid(value, "Capacity pool") }
  end
end
