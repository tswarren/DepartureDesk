require "ostruct"

class ActivateSupplierArrangementVersion < AgencyCommand
  include ArrangementCommandSupport

  ATTESTATION_VERSION = "m3e2-v1"

  def initialize(agency:, actor:, arrangement:, idempotency_key:,
    version: nil, arrangement_lock_version: nil, version_lock_version: nil,
    evidence_attributes: nil, confirmation_attributes: nil,
    existing_confirmation_id: nil, supplier_confirmation_id: nil,
    identifier_attributes: nil, cost_source_coverage_acknowledged: false,
    provisional_costs_acknowledged: false,
    commitment_trigger_coverage_acknowledged: false,
    elapsed_deadlines_acknowledged: false,
    confirmed_quantity: nil, confirmed_amount_minor_units: nil,
    confirmed_quantities: nil, confirmed_amounts_minor_units: nil,
    acknowledgments: nil, duplicate_acknowledgement_token: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @idempotency_key = idempotency_key
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @evidence_attributes = (evidence_attributes || confirmation_attributes || {}).to_h.with_indifferent_access
    @existing_confirmation_id = existing_confirmation_id || supplier_confirmation_id
    identifier_input = identifier_attributes&.to_h&.with_indifferent_access
    @identifier_attributes = identifier_input if identifier_input&.values&.any?(&:present?)
    acknowledgments = acknowledgments&.to_h&.with_indifferent_access || {}
    @cost_source_ack = boolean(acknowledgments.fetch(
      :cost_source_coverage, cost_source_coverage_acknowledged
    ))
    @provisional_ack = boolean(acknowledgments.fetch(
      :provisional_costs, provisional_costs_acknowledged
    ))
    @trigger_ack = boolean(acknowledgments.fetch(
      :commitment_trigger_coverage, commitment_trigger_coverage_acknowledged
    ))
    @elapsed_deadlines_ack = boolean(acknowledgments.fetch(
      :elapsed_deadlines, elapsed_deadlines_acknowledged
    ))
    @confirmed_quantity = confirmed_quantity
    @confirmed_amount_minor_units = confirmed_amount_minor_units
    @confirmed_quantities = (confirmed_quantities || {}).to_h.with_indifferent_access
    @confirmed_amounts_minor_units = (confirmed_amounts_minor_units || {}).to_h.with_indifferent_access
    @duplicate_acknowledgement_token = duplicate_acknowledgement_token
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.find_by(id: @arrangement&.id)
      raise ActiveRecord::RecordNotFound unless arrangement

      version = resolve_version(arrangement)
      lock_activation_suppliers!(arrangement, version)
      departure = @agency.departures.lock.find(arrangement.departure_id)
      arrangement = @agency.supplier_arrangements.lock.find(arrangement.id)
      locked_versions = arrangement.versions.where(
        id: [ arrangement.governing_version_id, version.id ].compact
      ).order(:version_number, :id).lock.index_by(&:id)
      version = locked_versions.fetch(version.id)
      predecessor = arrangement.governing_version_id &&
        locked_versions.fetch(arrangement.governing_version_id)
      lock_exact_graph!(version, arrangement)

      payload = activation_payload(arrangement, version)
      if (replay = replay_idempotency(key, payload))
        return replay
      end

      activation_kind = validate_state!(departure, arrangement, version, predecessor)
      ensure_submitted_lock!(arrangement, @arrangement_lock_version)
      ensure_submitted_lock!(version, @version_lock_version)
      readiness = SupplierArrangementActivationReadiness.new(
        agency: @agency, arrangement: arrangement, version: version
      ).call
      unless readiness.ready?
        message = readiness.blockers.map(&:message).uniq.to_sentence
        raise Error.new(message, code: :invalid)
      end
      validate_acknowledgments!(readiness)
      activated_at = Time.current
      validate_elapsed_deadline_acknowledgment!(version, departure, at: activated_at)
      confirmation = resolve_confirmation!(
        arrangement: arrangement, version: version, recorded_at: activated_at
      )
      identifier = resolve_identifier!(confirmation, arrangement)
      activation = create_manifest!(
        arrangement: arrangement, version: version, confirmation: confirmation,
        predecessor: predecessor, activation_kind: activation_kind,
        readiness: readiness, activated_at: activated_at
      )
      create_cost_selections!(activation, readiness)
      capacity_events = create_capacity_entries!(activation, version, activated_at)
      commitments = create_commitments!(activation, version, confirmation)
      deadline_result = materialize_deadlines!(
        activation:, arrangement:, version:, departure:,
        predecessor_version: predecessor, at: activated_at
      )
      commitments.concat(deadline_result[:commitments])
      create_confirmation_links!(
        activation: activation, confirmation: confirmation, identifier: identifier,
        capacity_events: capacity_events
      )

      if predecessor
        predecessor.update!(status: "superseded", superseded_at: activated_at)
      end
      version.update!(status: "activated", activated_at: activated_at)
      arrangement.update!(status: "active", governing_version: version)
      audit_activation!(
        arrangement, activation, capacity_events, commitments,
        deadline_result[:occurrences],
        successor: activation_kind == "successor"
      )
      claim_idempotency!(key, payload, activation)
      Result.new(status: :created, record: activation)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("The arrangement was activated by another request.", code: :conflict)
  end

  private

  def boolean(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def resolve_version(arrangement)
    scope = arrangement.versions
    candidate = @version ? scope.find_by(id: @version.id) : scope.find_by(status: "draft")
    raise ActiveRecord::RecordNotFound unless candidate

    candidate
  end

  def lock_activation_suppliers!(arrangement, version)
    supplier_ids = [ arrangement.contracting_supplier_id ]
    supplier_ids.concat(version.arrangement_item_definitions.pluck(:default_service_provider_id))
    supplier_ids.concat(version.service_occurrence_definitions.pluck(:service_provider_id))
    pool_ids = version.capacity_pool_definitions.pluck(:capacity_pool_id)
    supplier_ids.concat(@agency.capacity_pools.where(id: pool_ids).pluck(:supplying_supplier_id))
    supplier_ids.concat(version.supplier_cost_sources.pluck(:charging_supplier_id))
    supplier_ids.concat(version.supplier_commitment_trigger_definitions.pluck(:committed_supplier_id))
    lock_suppliers_in_uuid_order!(supplier_ids)
  end

  def lock_exact_graph!(version, arrangement)
    %i[
      arrangement_item_definitions service_occurrence_definitions
      supplier_resource_definitions capacity_pair_definitions
      supplier_cost_sources supplier_cost_definitions supplier_cost_components
      supplier_cost_participant_categories
      supplier_cost_usage_assumptions supplier_cost_occupancy_profiles
      supplier_commitment_trigger_definitions
      supplier_deadline_definitions
    ].each { |association| version.public_send(association).order(:id).lock.load }
    [
      SupplierCostComponentBase,
      SupplierCostOccupancyProfilePosition,
      SupplierDeadlineDefinitionCoverageLink,
      SupplierDeadlineCommitmentDefinitionLine
    ].each do |model|
      model.where(supplier_arrangement_version_id: version.id).order(:id).lock.load
    end
    pools = arrangement.capacity_pools.where(
      id: version.capacity_pool_definitions.select(:capacity_pool_id)
    ).order(:id).lock.to_a
    version.capacity_pool_definitions.order(:id).lock.load
    pools.each do |pool|
      pool.capacity_events.order(:id).lock.load
      pool.capacity_projection&.lock!
      pool.capacity_reconciliations.order(:id).lock.load
    end
  end

  def validate_state!(departure, arrangement, version, predecessor)
    unless departure.active?
      raise Error.new("Only an active departure can activate an arrangement.", code: :invalid_state)
    end
    sole_draft = arrangement.versions.where(status: "draft").sole
    if arrangement.draft? && arrangement.governing_version_id.nil? &&
        predecessor.nil? && version.id == sole_draft.id && version.copied_from_id.nil?
      return "first"
    end
    if arrangement.active? && predecessor&.activated? &&
        arrangement.governing_version_id == predecessor.id &&
        version.id == sole_draft.id && version.copied_from_id == predecessor.id
      return "successor"
    end
    raise Error.new("Only the sole editable draft version can be activated.", code: :invalid_state)
  rescue ActiveRecord::SoleRecordExceeded, ActiveRecord::RecordNotFound
    raise Error.new("Only the sole editable draft version can be activated.", code: :invalid_state)
  end

  def ensure_submitted_lock!(record, submitted)
    if submitted.nil? || record.lock_version != submitted.to_i
      raise Error.new(STALE_MESSAGE, code: :conflict)
    end
  end

  def validate_acknowledgments!(readiness)
    unless @cost_source_ack
      raise Error.new("Acknowledge complete entered cost-source coverage.", code: :invalid)
    end
    unless @trigger_ack
      raise Error.new("Acknowledge known confirmation-trigger coverage.", code: :invalid)
    end
    estimates = readiness.cost_selections.select { |_source, definition| definition.estimate? }
    if estimates.any? && !@provisional_ack
      raise Error.new("Acknowledge every listed provisional estimate source.", code: :invalid)
    end
  end

  def validate_elapsed_deadline_acknowledgment!(version, departure, at:)
    elapsed = MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
      agency: @agency, actor: @actor, arrangement: version.supplier_arrangement,
      version:, activation: nil, departure:, at:
    ).preview_elapsed
    return if elapsed.empty?
    return if @elapsed_deadlines_ack

    raise Error.new(
      "Acknowledge already-elapsed Deadline occurrences before activation.", code: :invalid
    )
  end

  def materialize_deadlines!(activation:, arrangement:, version:, departure:,
    predecessor_version:, at:)
    result = MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
      agency: @agency, actor: @actor, arrangement:, version:, activation:, departure:,
      predecessor_version:, at:
    ).call
    if result[:occurrences].any?
      audit!(
        agency: @agency, actor: @actor, subject: arrangement,
        action: "supplier_arrangement.deadlines_materialized",
        details: {
          "supplier_arrangement_activation_id" => activation.id,
          "supplier_deadline_occurrence_ids" => result[:occurrences].map(&:id),
          "supplier_commitment_ids" => result[:commitments].map(&:id)
        }
      )
    end
    result
  end

  def resolve_confirmation!(arrangement:, version:, recorded_at:)
    if @existing_confirmation_id.present?
      if @evidence_attributes.values.any?(&:present?)
        raise Error.new("Choose existing evidence or enter new evidence, not both.", code: :invalid)
      end
      confirmation = SupplierConfirmation.where(agency_id: @agency.id)
        .lock.find_by(id: @existing_confirmation_id)
      raise ActiveRecord::RecordNotFound unless confirmation
      ensure_confirmation_compatible!(confirmation, arrangement, version)
      return confirmation
    end

    attrs = normalized_confirmation_attributes
    confirmation = SupplierConfirmation.create!(
      owner_attributes(arrangement, version).merge(
        confirming_supplier_id: arrangement.contracting_supplier_id,
        actor: @actor,
        recorded_at: recorded_at,
        **attrs
      )
    )
    ensure_confirmation_compatible!(confirmation, arrangement, version)
    confirmation
  end

  def normalized_confirmation_attributes
    kind = @evidence_attributes[:evidence_kind].to_s.strip
    unless SupplierConfirmation::BOOKING_EVIDENCE_KINDS.include?(kind)
      raise Error.new("Choose valid Supplier confirmation evidence.", code: :invalid)
    end
    other_label = @evidence_attributes[:other_evidence_label].to_s.strip.presence
    if (kind == "other") != other_label.present?
      raise Error.new("Enter an other evidence label only for other evidence.", code: :invalid)
    end
    evidence_on = parse_date(@evidence_attributes[:evidence_on], "Evidence date")
    channel = @evidence_attributes[:channel].to_s.strip
    note = @evidence_attributes[:reference_note].to_s.strip
    reason = @evidence_attributes[:confirmed_without_identifier_reason].to_s.strip.presence
    if evidence_on.blank? || channel.blank? || note.blank?
      raise Error.new("Enter complete Supplier confirmation evidence.", code: :invalid)
    end
    if @identifier_attributes.blank? && reason.blank?
      raise Error.new(
        "Enter a Supplier identifier or explain why this is confirmed without one.", code: :invalid
      )
    end
    {
      evidence_kind: kind, other_evidence_label: other_label, evidence_on: evidence_on,
      channel: channel, reference_note: note,
      confirmed_without_identifier_reason: reason
    }
  end

  def ensure_confirmation_compatible!(confirmation, arrangement, version)
    compatible = confirmation.agency_id == @agency.id &&
      confirmation.departure_id == arrangement.departure_id &&
      confirmation.supplier_arrangement_id == arrangement.id &&
      confirmation.supplier_arrangement_version_id == version.id &&
      confirmation.confirming_supplier_id == arrangement.contracting_supplier_id
    unless compatible
      raise Error.new("That confirmation is not compatible with this exact version.", code: :invalid)
    end
  end

  def resolve_identifier!(confirmation, arrangement)
    return if @identifier_attributes.blank?

    type = @identifier_attributes[:identifier_type].to_s.strip
    unless SupplierIssuedIdentifier::IDENTIFIER_TYPES.include?(type)
      raise Error.new("Choose a valid Supplier identifier type.", code: :invalid)
    end
    display = @identifier_attributes[:display_value].to_s.strip
    normalized = display.downcase
    issuer = @identifier_attributes[:issuer_context].to_s.strip
    other_label = @identifier_attributes[:other_type_label].to_s.strip.presence
    if display.blank? || issuer.blank? || ((type == "other") != other_label.present?)
      raise Error.new("Enter a complete qualified Supplier identifier.", code: :invalid)
    end
    lookup = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: arrangement.contracting_supplier_id,
      identifier_type: type,
      issuer_context: issuer,
      normalized_value: normalized,
      arrangement: arrangement,
      reservation: nil
    )
    if lookup.foreign.any?
      fingerprint = DuplicateAcknowledgement.fingerprint(
        supplier_id: arrangement.contracting_supplier_id,
        identifier_type: type,
        issuer_context: issuer,
        normalized_value: normalized
      )
      candidates = lookup.foreign.map do |row|
        OpenStruct.new(id: row.id, signals: [ "supplier_issued_identifier", row.display_value ])
      end
      candidate_digest = DuplicateAcknowledgement.candidate_digest(candidates)
      if @duplicate_acknowledgement_token.blank?
        raise DuplicateReviewRequired.new(
          token: DuplicateAcknowledgement.issue(
            "shape" => "create",
            "command" => "supplier_issued_identifier.create",
            "agency_id" => @agency.id,
            "actor_id" => @actor.id,
            "fingerprint" => fingerprint,
            "candidate_digest" => candidate_digest
          ),
          candidates: candidates
        )
      end
      payload = DuplicateAcknowledgement.verify!(
        @duplicate_acknowledgement_token,
        agency: @agency, actor: @actor, command: "supplier_issued_identifier.create"
      )
      unless payload["fingerprint"] == fingerprint
        raise Error.new("That acknowledgement does not match this identifier.", code: :conflict)
      end
      unless payload["candidate_digest"] == candidate_digest
        raise Error.new("Duplicate candidates changed. Review them again.", code: :conflict)
      end
      if DuplicateAcknowledgement.expired?(payload)
        raise Error.new("That acknowledgement has expired.", code: :invalid)
      end
    end
    lookup.same_owner.first ||
      SupplierIssuedIdentifier.create!(
        agency: @agency, departure_id: arrangement.departure_id,
        supplier_arrangement: arrangement,
        supplier_id: arrangement.contracting_supplier_id,
        issuer_context: issuer, identifier_type: type,
        other_type_label: other_label, display_value: display,
        normalized_value: normalized, first_supplier_confirmation: confirmation
      )
  end

  def create_manifest!(
    arrangement:, version:, predecessor:, activation_kind:, confirmation:, readiness:, activated_at:
  )
    SupplierArrangementActivation.create!(
      owner_attributes(arrangement, version).merge(
        activation_kind: activation_kind,
        predecessor_version: predecessor,
        predecessor_activation: predecessor&.supplier_arrangement_activation,
        supplier_confirmation: confirmation,
        actor: @actor, activated_at: activated_at,
        coverage_attestation_version: ATTESTATION_VERSION,
        coverage_fingerprint: coverage_fingerprint(version, readiness),
        cost_source_coverage_acknowledged: @cost_source_ack,
        provisional_costs_acknowledged: @provisional_ack,
        commitment_trigger_coverage_acknowledged: @trigger_ack,
        elapsed_deadlines_acknowledged: @elapsed_deadlines_ack
      )
    )
  end

  def create_cost_selections!(activation, readiness)
    readiness.cost_selections.each do |source, definition|
      activation.cost_selections.create!(
        owner_attributes(activation.supplier_arrangement, activation.supplier_arrangement_version).merge(
          supplier_cost_source: source,
          supplier_cost_definition: definition,
          selection_kind: definition.contracted? ? "contracted" : "provisional_estimate"
        )
      )
    end
  end

  def create_capacity_entries!(activation, version, activated_at)
    events = []
    version.capacity_pool_definitions.includes(:capacity_pool).order(:id).each do |definition|
      pool = definition.capacity_pool
      carried = pool.capacity_events.exists?
      event = if pool.numeric_inventory? && !carried
        EstablishCapacityAlreadyLocked.new(
          definition: definition, actor: @actor, recorded_at: activated_at
        ).call
      end
      events << event if event
      activation.capacity_entries.create!(
        owner_attributes(activation.supplier_arrangement, version).merge(
          capacity_pool_definition: definition, capacity_pool: pool,
          establishment_event: event,
          entry_kind: event ? "established" : (carried ? "carried" : "nonnumeric")
        )
      )
    end
    events
  end

  def create_commitments!(activation, version, confirmation)
    version.supplier_commitment_trigger_definitions
      .where(trigger_kind: "arrangement_confirmation").order(:position, :id).map do |trigger|
      OpenSupplierCommitmentAlreadyLocked.new(
        trigger: trigger, confirmation: confirmation, actor: @actor,
        activation: activation,
        confirmed_quantity: activation_confirmed_quantity_for(trigger),
        confirmed_quantity_basis: trigger.quantity_basis,
        confirmed_amount_minor_units: activation_confirmed_amount_for(trigger)
      ).call
    end
  end

  def activation_confirmed_quantity_for(trigger)
    @confirmed_quantities[trigger.id].presence ||
      @confirmed_quantities[trigger.id.to_s].presence ||
      @confirmed_quantity
  end

  def activation_confirmed_amount_for(trigger)
    @confirmed_amounts_minor_units[trigger.id].presence ||
      @confirmed_amounts_minor_units[trigger.id.to_s].presence ||
      @confirmed_amount_minor_units
  end

  def create_confirmation_links!(activation:, confirmation:, identifier:, capacity_events:)
    owner = owner_attributes(activation.supplier_arrangement, activation.supplier_arrangement_version)
    SupplierConfirmationActivationLink.create!(
      owner.merge(supplier_confirmation: confirmation, supplier_arrangement_activation: activation)
    )
    if identifier
      SupplierConfirmationIdentifierLink.find_or_create_by!(
        owner.merge(supplier_confirmation: confirmation, supplier_issued_identifier: identifier)
      )
    end
    capacity_events.each do |event|
      next unless event.supplying_supplier_id == confirmation.confirming_supplier_id

      SupplierConfirmationCapacityEventLink.create!(
        owner.merge(supplier_confirmation: confirmation, capacity_event: event)
      )
    end
  end

  def owner_attributes(arrangement, version)
    {
      agency: @agency, departure_id: arrangement.departure_id,
      supplier_arrangement: arrangement, supplier_arrangement_version: version
    }
  end

  def coverage_fingerprint(version, readiness)
    payload_digest(
      version_id: version.id,
      cost_selections: readiness.cost_selections.map { |source, definition| [ source.id, definition.id ] },
      capacity_definitions: version.capacity_pool_definitions.order(:id).pluck(:id),
      triggers: version.supplier_commitment_trigger_definitions.order(:id).pluck(:id),
      deadlines: version.supplier_deadline_definitions.order(:id).pluck(:id),
      acknowledgments: [ @cost_source_ack, @provisional_ack, @trigger_ack, @elapsed_deadlines_ack ]
    )
  end

  def activation_payload(arrangement, version)
    {
      supplier_arrangement_id: arrangement.id,
      supplier_arrangement_version_id: version.id,
      arrangement_lock_version: @arrangement_lock_version,
      version_lock_version: @version_lock_version,
      existing_confirmation_id: @existing_confirmation_id,
      evidence: @evidence_attributes.to_h,
      identifier: @identifier_attributes&.to_h,
      cost_source_coverage_acknowledged: @cost_source_ack,
      provisional_costs_acknowledged: @provisional_ack,
      commitment_trigger_coverage_acknowledged: @trigger_ack,
      elapsed_deadlines_acknowledged: @elapsed_deadlines_ack,
      confirmed_quantity: @confirmed_quantity,
      confirmed_amount_minor_units: @confirmed_amount_minor_units,
      confirmed_quantities: @confirmed_quantities,
      confirmed_amounts_minor_units: @confirmed_amounts_minor_units
    }
  end

  def replay_idempotency(key, payload)
    lock_idempotency_slot!(self.class.name, key)
    existing = @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
    return unless existing
    unless existing.payload_digest == payload_digest(payload)
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(status: :replayed, record: SupplierArrangementActivation.find(existing.result_record_id))
  end

  def claim_idempotency!(key, payload, activation)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency, command_name: self.class.name, idempotency_key: key,
      payload_digest: payload_digest(payload),
      result_record_type: SupplierArrangementActivation.name,
      result_record_id: activation.id
    )
  end

  def audit_activation!(arrangement, activation, events, commitments, occurrences, successor:)
    audit!(
      agency: @agency,
      action: successor ? "supplier_arrangement.successor_activated" : "supplier_arrangement.activated",
      subject: arrangement, actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => activation.supplier_arrangement_version_id,
        "supplier_arrangement_activation_id" => activation.id,
        "supplier_confirmation_id" => activation.supplier_confirmation_id,
        "predecessor_version_id" => activation.predecessor_version_id,
        "capacity_event_ids" => events.map(&:id),
        "supplier_commitment_ids" => commitments.map(&:id),
        "supplier_deadline_occurrence_ids" => occurrences.map(&:id),
        "cost_source_coverage_acknowledged" => @cost_source_ack,
        "provisional_costs_acknowledged" => @provisional_ack,
        "commitment_trigger_coverage_acknowledged" => @trigger_ack,
        "elapsed_deadlines_acknowledged" => @elapsed_deadlines_ack
      }
    )
  end
end
