# frozen_string_literal: true

class ConfirmAndActivateCruiseGroup < AgencyCommand
  include CostCommandSupport

  PROVENANCE = "Confirmed during Cruise activation review"
  ATTESTATION_NOTE = "Confirmed during activation of this version"

  def initialize(agency:, actor:, arrangement:, version:, idempotency_key:,
    terms_acknowledged:, arrangement_lock_version:, version_lock_version:,
    evidence_attributes: {}, supplier_reference: nil, existing_confirmation_id: nil,
    opening_overrides: {}, elapsed_deadlines_acknowledged: false,
    confirmed_quantities: {}, confirmed_amounts_minor_units: {},
    duplicate_acknowledgement_token: nil, forged_evidence_policy: false)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @idempotency_key = idempotency_key
    @terms_acknowledged = ActiveModel::Type::Boolean.new.cast(terms_acknowledged)
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
    @evidence_attributes = evidence_attributes.to_h.with_indifferent_access
    @supplier_reference = supplier_reference.to_s.strip.presence
    @existing_confirmation_id = existing_confirmation_id.presence
    @opening_overrides = normalize_overrides(opening_overrides)
    @elapsed_deadlines_acknowledged = ActiveModel::Type::Boolean.new.cast(elapsed_deadlines_acknowledged)
    @confirmed_quantities = confirmed_quantities.to_h
    @confirmed_amounts_minor_units = confirmed_amounts_minor_units.to_h
    @duplicate_acknowledgement_token = duplicate_acknowledgement_token
    @forged_evidence_policy = forged_evidence_policy
  end

  def call
    ensure_arrangement_actor!
    unless @terms_acknowledged
      raise Error.new(
        "Confirm that the displayed inventory and rates are the Supplier agreement for this exact version.",
        code: :invalid
      )
    end
    if @forged_evidence_policy
      raise Error.new("That confirmation evidence policy cannot be selected.", code: :invalid)
    end

    key = normalize_idempotency_key(@idempotency_key)
    result = ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.lock.find(@arrangement.id)
      version = arrangement.versions.lock.find(@version.id)
      payload = submitted_payload(arrangement, version)
      if (replay = replay_idempotency(key, payload))
        return replay
      end

      ensure_current_lock_version!(arrangement, @arrangement_lock_version)
      ensure_current_lock_version!(version, @version_lock_version)
      ensure_confirmable!(arrangement, version)
      ensure_proof_choice!
      confirmation = resolve_confirmation!(arrangement, version)
      stamp_contract_reviews!(arrangement, version)
      record_opening_authority!(arrangement, version, confirmation)
      arrangement.reload
      version.reload
      readiness = SupplierArrangementActivationReadiness.new(
        agency: @agency, arrangement: arrangement, version: version
      ).call
      unless readiness.ready?
        raise Error.new(readiness.blockers.map(&:message).uniq.to_sentence, code: :invalid)
      end

      result = ActivateSupplierArrangementVersion.new(
        agency: @agency,
        actor: @actor,
        arrangement: arrangement,
        version: version,
        arrangement_lock_version: arrangement.lock_version,
        version_lock_version: version.lock_version,
        idempotency_key: key,
        existing_confirmation_id: confirmation.id,
        cost_source_coverage_acknowledged: true,
        provisional_costs_acknowledged: false,
        commitment_trigger_coverage_acknowledged: true,
        elapsed_deadlines_acknowledged: @elapsed_deadlines_acknowledged,
        confirmed_quantities: @confirmed_quantities,
        confirmed_amounts_minor_units: @confirmed_amounts_minor_units,
        duplicate_acknowledgement_token: @duplicate_acknowledgement_token,
        allow_relaxed_confirmation: true
      ).call
      link_opening_confirmation!(arrangement, version, confirmation)
      claim_idempotency!(key, payload, result.record)
      result
    end
    result
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  def replay_if_recorded
    ensure_arrangement_actor!
    unless @terms_acknowledged
      raise Error.new(
        "Confirm that the displayed inventory and rates are the Supplier agreement for this exact version.",
        code: :invalid
      )
    end
    if @forged_evidence_policy
      raise Error.new("That confirmation evidence policy cannot be selected.", code: :invalid)
    end

    key = normalize_idempotency_key(@idempotency_key)
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.lock.find(@arrangement.id)
      version = arrangement.versions.lock.find(@version.id)
      replay_idempotency(key, submitted_payload(arrangement, version))
    end
  end

  private

  def normalize_overrides(raw)
    raw.to_h.each_with_object({}) do |(id, reason), overrides|
      text = reason.to_s.strip
      next if text.blank?

      overrides[id.to_s] = text
    end
  end

  def submitted_payload(arrangement, version)
    {
      supplier_arrangement_id: arrangement.id,
      supplier_arrangement_version_id: version.id,
      arrangement_lock_version: @arrangement_lock_version.to_s,
      version_lock_version: @version_lock_version.to_s,
      terms_acknowledged: @terms_acknowledged,
      existing_confirmation_id: @existing_confirmation_id,
      evidence: @evidence_attributes.to_h,
      supplier_reference: @supplier_reference,
      opening_overrides: @opening_overrides,
      elapsed_deadlines_acknowledged: @elapsed_deadlines_acknowledged,
      confirmed_quantities: @confirmed_quantities,
      confirmed_amounts_minor_units: @confirmed_amounts_minor_units,
      duplicate_acknowledgement_token: @duplicate_acknowledgement_token
    }
  end

  def ensure_confirmable!(arrangement, version)
    review = CompileCruiseActivationReview.new(
      agency: @agency, arrangement: arrangement, version: version, presentation: false
    ).call
    return if review.activation_confirmable?

    raise Error.new("This Cruise review cannot activate these terms.", code: :invalid)
  end

  def ensure_proof_choice!
    new_proof = @evidence_attributes[:evidence_kind].present?
    if @existing_confirmation_id.present? && new_proof
      raise Error.new("Choose existing Supplier proof or record new proof.", code: :invalid)
    end
    return if @existing_confirmation_id.present? || new_proof

    raise Error.new("Choose Supplier proof.", code: :invalid)
  end

  def resolve_confirmation!(arrangement, version)
    if @existing_confirmation_id.present?
      confirmation = version.supplier_confirmations.find_by(id: @existing_confirmation_id)
      unless confirmation&.confirming_supplier_id == arrangement.contracting_supplier_id
        raise Error.new("That confirmation is not compatible with this exact version.", code: :invalid)
      end
      unless SupplierConfirmation::BOOKING_EVIDENCE_KINDS.include?(confirmation.evidence_kind)
        raise Error.new("Choose valid Supplier confirmation evidence.", code: :invalid)
      end

      return confirmation
    end

    identifier = if @supplier_reference
      {
        identifier_type: "group_number",
        issuer_context: arrangement.contracting_supplier.display_name_for_directory,
        display_value: @supplier_reference
      }
    end
    RecordSupplierConfirmationEvidence.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      version: version,
      recorded_at: Time.current,
      evidence_attributes: @evidence_attributes,
      identifier_attributes: identifier,
      duplicate_acknowledgement_token: @duplicate_acknowledgement_token,
      evidence_policy: :cruise_activation
    ).call.record
  end

  def stamp_contract_reviews!(arrangement, version)
    occurrence_id = version.service_occurrence_definitions.order(:id).pick(:service_occurrence_id)
    version.supplier_resource_definitions.order(:position, :id).each do |resource_definition|
      sources = version.supplier_cost_sources.where(
        arrangement_item_id: resource_definition.arrangement_item_id,
        service_occurrence_id: occurrence_id,
        supplier_resource_id: resource_definition.supplier_resource_id
      )
      if sources.empty?
        raise Error.new("Cabin #{resource_definition.name} needs ready contracted Supplier rates.", code: :invalid)
      end

      sources.each do |source|
        definition = source.supplier_cost_definitions.where(stage: "contracted").order(:created_at, :id).last
        unless definition
          raise Error.new("Cabin #{resource_definition.name} needs ready contracted Supplier rates.", code: :invalid)
        end

        definition = lock_definition!(source, definition)
        next if definition.contract_review_current?

        validate_ready!(definition, require_usage: false)
        fingerprint = definition_fingerprint(definition)
        definition.update!(
          contract_reviewed_by: @actor,
          contract_reviewed_at: Time.current,
          contract_review_provenance: PROVENANCE,
          contract_review_fingerprint: fingerprint
        )
        audit_cost!("supplier_arrangement.cost_definition_contract_reviewed", arrangement, version, {
          "supplier_cost_source_id" => source.id,
          "supplier_cost_definition_id" => definition.id,
          "stage" => definition.stage,
          "contract_review_provenance" => PROVENANCE,
          "contract_review_fingerprint" => fingerprint,
          "contract_reviewed_by_id" => @actor.id
        })
      end
    end
  end

  def record_opening_authority!(arrangement, version, confirmation)
    definitions = version.capacity_pool_definitions.includes(:capacity_pool).index_by { |definition| definition.id.to_s }
    if @opening_overrides.any?
      ensure_permitted!(@actor, :override_supplier_planning_terms)
    end

    @opening_overrides.each do |id, reason|
      definition = definitions[id]
      unless definition&.capacity_pool&.numeric_inventory?
        raise Error.new("That cabin is not on this version.", code: :invalid)
      end
      if definition.proposed_opening_quantity.to_i <= 0
        raise Error.new("That cabin does not have an opening quantity.", code: :invalid)
      end
      if opening_authority?(definition)
        raise Error.new("That cabin already has opening authority.", code: :invalid)
      end

      reason = normalize_text(reason, "Override explanation", CapacityPoolDefinition::OVERRIDE_REASON_LIMIT)
      definition.update!(
        evidence_kind: nil,
        evidence_on: nil,
        evidence_reference_note: nil,
        evidence_external_reference: nil,
        evidence_on_origin: nil,
        evidence_reference_origin: nil,
        override: true,
        override_reason: reason,
        opening_authority_confirmation: nil
      )
      audit_pool!(arrangement, version, definition, "override")
    end

    kind = confirmation.evidence_kind
    unless CapacityPoolDefinition::EVIDENCE_KINDS.include?(kind)
      raise Error.new("Choose valid Supplier confirmation evidence.", code: :invalid)
    end

    definitions.each_value do |definition|
      next unless definition.capacity_pool.numeric_inventory?
      next unless definition.proposed_opening_quantity.to_i.positive?
      next if opening_authority?(definition) || @opening_overrides.key?(definition.id.to_s)

      date, date_origin = evidence_date(version, confirmation)
      note, note_origin = evidence_note(confirmation)
      definition.update!(
        evidence_kind: kind,
        evidence_on: date,
        evidence_reference_note: note,
        evidence_external_reference: nil,
        evidence_on_origin: date_origin,
        evidence_reference_origin: note_origin,
        override: false,
        override_reason: nil,
        opening_authority_confirmation: confirmation
      )
      audit_pool!(arrangement, version, definition, "evidence")
    end
  end

  def evidence_date(version, confirmation)
    return [ confirmation.evidence_on, "supplied" ] if confirmation.evidence_on.present?

    agreement = version.supplier_arrangement_cruise_agreement_confirmations.find_by(current: true)
    date = agreement&.contract_date
    if date.blank?
      raise Error.new("Confirm the Cruise group number and contract date before activation.", code: :invalid)
    end

    [ date, "agreement_contract_date" ]
  end

  def evidence_note(confirmation)
    reference = confirmation.supplier_issued_identifiers.order(:created_at, :id).pick(:display_value).to_s.strip.presence
    note = confirmation.reference_note.to_s.strip.presence
    combined = [ reference, note ].compact.uniq.join("\n")
    limit = CapacityPoolDefinition::EVIDENCE_REFERENCE_NOTE_LIMIT
    return [ combined, "supplier" ] if combined.present? && combined.length <= limit
    return [ reference, "supplier" ] if reference.present? && reference.length <= limit
    return [ note, "supplier" ] if note.present? && note.length <= limit
    return [ ATTESTATION_NOTE, "activation_attestation" ] if combined.blank?

    [ "Recorded on the Supplier confirmation for this activation.", "activation_attestation" ]
  end

  def opening_authority?(definition)
    definition.override? || (
      definition.evidence_kind.present? &&
      definition.evidence_on.present? &&
      definition.evidence_reference_note.present?
    )
  end

  def link_opening_confirmation!(arrangement, version, confirmation)
    version.capacity_pool_definitions.where(opening_authority_confirmation: confirmation).find_each do |definition|
      event = definition.capacity_pool.capacity_events.find_by!(
        supplier_arrangement_version: version, event_type: "established"
      )
      SupplierConfirmationCapacityEventLink.find_or_create_by!(
        agency: @agency,
        departure_id: arrangement.departure_id,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        supplier_confirmation: confirmation,
        capacity_event: event
      )
    end
  end

  def audit_pool!(arrangement, version, definition, authority)
    audit!(
      agency: @agency,
      action: "supplier_arrangement.capacity_pool_updated",
      subject: arrangement,
      actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => version.id,
        "capacity_pool_id" => definition.capacity_pool_id,
        "capacity_pool_definition_id" => definition.id,
        "opening_authority" => authority
      }
    )
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
end
