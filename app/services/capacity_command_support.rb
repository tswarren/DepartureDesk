module CapacityCommandSupport
  extend ActiveSupport::Concern

  include ArrangementCommandSupport

  CAPACITY_LABEL_LIMIT = CapacityPoolDefinition::LABEL_LIMIT
  CAPACITY_NOTES_LIMIT = CapacityPoolDefinition::NOTES_LIMIT
  CAPACITY_UNIT_LABEL_LIMIT = CapacityPoolDefinition::UNIT_LABEL_LIMIT
  CAPACITY_EVIDENCE_NOTE_LIMIT = CapacityPoolDefinition::EVIDENCE_REFERENCE_NOTE_LIMIT
  CAPACITY_EVIDENCE_EXTERNAL_LIMIT = CapacityPoolDefinition::EVIDENCE_EXTERNAL_REFERENCE_LIMIT
  CAPACITY_OVERRIDE_REASON_LIMIT = CapacityPoolDefinition::OVERRIDE_REASON_LIMIT
  CAPACITY_EVENT_DIRECTIONS = CapacityTimelineReplay::DIRECTIONS.transform_values(&:sign).freeze

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

  def ensure_numeric_capacity_pool!(pool)
    return if pool.numeric_inventory?

    raise AgencyCommand::Error.new("Nonnumeric pools do not use the capacity event ledger.", code: :invalid_state)
  end

  def ensure_activated_capacity_graph!(departure, arrangement, version)
    return if (departure.draft? || departure.active?) && arrangement.active? && version.activated?

    raise AgencyCommand::Error.new("Capacity events require an activated supplier arrangement version.", code: :invalid_state)
  end

  def ensure_capacity_pool_established!(pool)
    return if pool.capacity_events.where(event_type: "established").exists?

    raise AgencyCommand::Error.new("Establish capacity before recording later events.", code: :invalid_state)
  end

  def ensure_capacity_pool_unestablished!(pool)
    return unless pool.capacity_events.exists?

    raise AgencyCommand::Error.new("Capacity has already been established for this pool.", code: :invalid_state)
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

  def normalize_capacity_event_quantity(value)
    quantity = value.is_a?(Integer) ? value : Integer(value, 10)
    return quantity if quantity.positive?

    raise AgencyCommand::Error.new("Capacity event quantity must be greater than zero.", code: :invalid)
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Capacity event quantity must be a whole number.", code: :invalid)
  end

  def normalize_effective_sequence(value)
    return nil if value.blank?

    sequence = value.is_a?(Integer) ? value : Integer(value, 10)
    return sequence if sequence.positive?

    raise AgencyCommand::Error.new("Effective sequence must be greater than zero.", code: :invalid)
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Effective sequence must be a whole number.", code: :invalid)
  end

  def normalize_recorded_at(value)
    return Time.current if value.blank?
    return value.in_time_zone if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s).tap do |parsed|
      raise AgencyCommand::Error.new("Recorded at is not a valid time.", code: :invalid) if parsed.blank?
    end
  rescue ArgumentError, TypeError
    raise AgencyCommand::Error.new("Recorded at is not a valid time.", code: :invalid)
  end

  def normalize_capacity_event_evidence_or_override(attrs)
    normalized = normalize_evidence_or_override(attrs)
    return normalized if normalized[:override]

    unless normalized[:evidence_kind].present? &&
        normalized[:evidence_on].present? &&
        normalized[:evidence_reference_note].present?
      raise AgencyCommand::Error.new("Enter complete supplier evidence.", code: :invalid)
    end

    normalized
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

  def next_capacity_event_sequence(pool, effective_on)
    pool.capacity_events.where(effective_on: effective_on).maximum(:effective_sequence).to_i + 1
  end

  def ensure_unused_capacity_event_sequence!(pool, effective_on, sequence)
    return unless pool.capacity_events.where(effective_on: effective_on, effective_sequence: sequence).exists?

    raise AgencyCommand::Error.new("That effective sequence is already used.", code: :conflict)
  end

  def resolve_capacity_applies_at(effective_on:, recorded_at:, time_zone:)
    zone = Time.find_zone!(time_zone)
    local_recorded_on = recorded_at.in_time_zone(time_zone).to_date
    return recorded_at if effective_on <= local_recorded_on

    zone.local(effective_on.year, effective_on.month, effective_on.day).advance(days: 1)
  end

  def lock_capacity_event_graph!(pool)
    pool = @agency.capacity_pools.lock.find(pool.id)
    departure = @agency.departures.lock.find(pool.departure_id)
    arrangement = @agency.supplier_arrangements.lock.find(pool.supplier_arrangement_id)
    version = arrangement.versions.lock.find_by!(status: "activated")
    item = arrangement.arrangement_items.lock.find(pool.arrangement_item_id)
    occurrence = item.service_occurrences.lock.find(pool.service_occurrence_id)
    resource = item.supplier_resources.lock.find(pool.supplier_resource_id)
    supplier = @agency.suppliers.lock.find(pool.supplying_supplier_id)
    [ departure, arrangement, version, item, occurrence, resource, supplier, pool ]
  end

  def ensure_capacity_event_timeline_nonnegative!(pool, candidate)
    events = pool.capacity_events.to_a + [ candidate ]
    CapacityTimelineReplay.new(events).call
  rescue CapacityTimelineReplay::NegativeQuantity
    raise AgencyCommand::Error.new("Capacity timeline cannot become negative.", code: :invalid_state)
  end

  def idempotent_capacity_event!(command_name:, idempotency_key:, payload:, event:)
    key = normalize_idempotency_key(idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(command_name, key)

    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency,
      command_name: command_name,
      idempotency_key: key
    ).lock.first
    if existing
      raise AgencyCommand::Error.new("That idempotency key was already used for different input.", code: :conflict) unless existing.payload_digest == digest

      return AgencyCommand::Result.new(status: :replayed, record: CapacityEvent.find(existing.result_record_id))
    end

    key_record = AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: command_name,
      idempotency_key: key,
      payload_digest: digest,
      result_record_type: CapacityEvent.name,
      result_record_id: event.id
    )
    event.agency_command_idempotency_key = key_record
    yield
    AgencyCommand::Result.new(status: :created, record: event)
  rescue ActiveRecord::RecordNotUnique
    raise AgencyCommand::Error.new("That idempotency key was already used for different input.", code: :conflict)
  end

  def record_capacity_event!(
    pool:,
    event_type:,
    quantity:,
    effective_on:,
    effective_sequence: nil,
    recorded_at: nil,
    projection_lock_version:,
    idempotency_key:,
    attributes: {},
    reinstates_event: nil,
    corrects_event_id: nil,
    capacity_reconciliation_id: nil
  )
    ensure_arrangement_actor!
    attrs = attributes.to_h.with_indifferent_access
    quantity = normalize_capacity_event_quantity(quantity)
    recorded_at = normalize_recorded_at(recorded_at)
    effective_on = parse_date(effective_on, "Effective date") || recorded_at.in_time_zone(pool.effective_time_zone).to_date
    submitted_sequence = normalize_effective_sequence(effective_sequence)
    evidence_attrs = normalize_capacity_event_evidence_or_override(attrs)
    corrects_event_id = parse_optional_uuid(corrects_event_id || attrs[:corrects_event_id], "Corrected event")
    capacity_reconciliation_id = parse_optional_uuid(
      capacity_reconciliation_id || attrs[:capacity_reconciliation_id],
      "Capacity reconciliation"
    )

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, item, occurrence, resource, supplier, locked_pool = lock_capacity_event_graph!(pool)
      ensure_activated_capacity_graph!(departure, arrangement, version)
      ensure_numeric_capacity_pool!(locked_pool)
      ensure_capacity_event_supplier_state!(supplier, event_type)
      RefreshDueCapacityProjection.new(agency: @agency, pool: locked_pool, now: recorded_at).call
      projection = locked_pool.capacity_projection || build_initial_capacity_projection(locked_pool, recorded_at)
      projection.lock! unless projection.new_record?

      event = locked_pool.capacity_events.build(
        agency: @agency,
        departure: departure,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        arrangement_item: item,
        service_occurrence: occurrence,
        supplier_resource: resource,
        supplying_supplier: supplier,
        event_type: event_type,
        quantity: quantity,
        measurement_basis: locked_pool.measurement_basis,
        effective_on: effective_on,
        effective_time_zone: locked_pool.effective_time_zone,
        applies_at: resolve_capacity_applies_at(
          effective_on: effective_on,
          recorded_at: recorded_at,
          time_zone: locked_pool.effective_time_zone
        ),
        effective_sequence: submitted_sequence || next_capacity_event_sequence(locked_pool, effective_on),
        recorded_at: recorded_at,
        actor: @actor,
        reinstates_event: reinstates_event,
        corrects_event_id: corrects_event_id,
        capacity_reconciliation_id: capacity_reconciliation_id,
        **evidence_attrs
      )
      payload = {
        capacity_pool_id: locked_pool.id,
        event_type: event_type,
        quantity: quantity,
        effective_on: effective_on,
        effective_sequence: submitted_sequence,
        recorded_at: recorded_at,
        reinstates_event_id: reinstates_event&.id,
        corrects_event_id: corrects_event_id,
        capacity_reconciliation_id: capacity_reconciliation_id,
        evidence: evidence_attrs
      }

      idempotent_capacity_event!(
        command_name: self.class.name,
        idempotency_key: idempotency_key,
        payload: payload,
        event: event
      ) do
        ensure_current_lock_version!(projection, projection_lock_version)
        ensure_capacity_event_preconditions!(locked_pool, event)
        ensure_unused_capacity_event_sequence!(locked_pool, event.effective_on, event.effective_sequence)
        ensure_capacity_event_timeline_nonnegative!(locked_pool, event)
        event.save!
        catch_up_capacity_projection!(locked_pool, projection, event, recorded_at)
        audit_capacity_event!(arrangement, event)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  def ensure_capacity_event_supplier_state!(supplier, event_type)
    return if supplier.active?
    return if %w[released withdrawn corrected_down].include?(event_type)
    return if event_type == "corrected_up" && @actor&.permitted?(:override_supplier_planning_terms)

    raise AgencyCommand::Error.new("That supplying supplier is not active.", code: :invalid_state)
  end

  def ensure_capacity_event_preconditions!(pool, event)
    if event.established?
      ensure_capacity_pool_unestablished!(pool)
      return
    end

    ensure_capacity_pool_established!(pool)
    ensure_reinstatement_capacity!(pool, event) if event.reinstated?
    ensure_correction_source!(pool, event) if event.corrected_up? || event.corrected_down?
  end

  def ensure_reinstatement_capacity!(pool, event)
    release = pool.capacity_events.lock.find(event.reinstates_event_id)
    unless release.released?
      raise AgencyCommand::Error.new("Reinstated capacity must reference a release event.", code: :invalid_state)
    end

    already_reinstated = pool.capacity_events.where(reinstates_event_id: release.id).sum(:quantity)
    return if already_reinstated + event.quantity <= release.quantity

    raise AgencyCommand::Error.new("Reinstated capacity cannot exceed the referenced release.", code: :invalid_state)
  end

  def ensure_correction_source!(pool, event)
    if event.corrects_event_id.present?
      pool.capacity_events.lock.find(event.corrects_event_id)
      return
    end
    if event.capacity_reconciliation_id.present?
      pool.capacity_reconciliations.lock.find(event.capacity_reconciliation_id)
      return
    end

    raise AgencyCommand::Error.new("Correction must reference exactly one source.", code: :invalid)
  end

  def build_initial_capacity_projection(pool, rebuilt_at)
    pool.build_capacity_projection(
      agency: @agency,
      departure: pool.departure,
      supplier_arrangement: pool.supplier_arrangement,
      arrangement_item: pool.arrangement_item,
      service_occurrence: pool.service_occurrence,
      supplier_resource: pool.supplier_resource,
      current_supplier_capacity: 0,
      rebuilt_at: rebuilt_at
    )
  end

  def catch_up_capacity_projection!(pool, projection, event, now)
    if event.applies_at <= now
      current = projection.current_supplier_capacity + CAPACITY_EVENT_DIRECTIONS.fetch(event.event_type) * event.quantity
      projection.current_supplier_capacity = current
      projection.last_event = event
      projection.last_effective_on = event.effective_on
      projection.last_effective_sequence = event.effective_sequence
      projection.last_recorded_at = event.recorded_at
    end
    next_event = pool.capacity_events.where("applies_at > ?", now).order(:applies_at, :effective_on, :effective_sequence, :recorded_at, :id).first
    projection.next_event = next_event
    projection.next_applies_at = next_event&.applies_at
    projection.rebuilt_at = now
    projection.save!
  end

  def audit_capacity_event!(arrangement, event)
    audit!(
      agency: @agency,
      action: "supplier_arrangement.capacity_event_recorded",
      subject: arrangement,
      actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => event.supplier_arrangement_version_id,
        "arrangement_item_id" => event.arrangement_item_id,
        "capacity_pool_id" => event.capacity_pool_id,
        "capacity_event_id" => event.id,
        "event_type" => event.event_type,
        "quantity" => event.quantity,
        "measurement_basis" => event.measurement_basis,
        "effective_on" => event.effective_on.iso8601,
        "effective_time_zone" => event.effective_time_zone,
        "effective_sequence" => event.effective_sequence,
        "applies_at" => event.applies_at.iso8601,
        "supplying_supplier_id" => event.supplying_supplier_id,
        "reinstates_event_id" => event.reinstates_event_id,
        "corrects_event_id" => event.corrects_event_id,
        "capacity_reconciliation_id" => event.capacity_reconciliation_id,
        "evidence_kind" => event.evidence_kind,
        "override" => event.override?
      }
    )
  end

  def capacity_definition_changed_fields(definition, attrs)
    attrs.keys.select { |field| definition.saved_change_to_attribute?(field) }.map(&:to_s)
  end

  def normalized_capacity_pool_id_list(values)
    Array(values).map { |value| parse_optional_uuid(value, "Capacity pool") }
  end
end
