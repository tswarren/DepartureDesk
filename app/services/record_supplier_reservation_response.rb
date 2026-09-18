# frozen_string_literal: true

require "ostruct"

class RecordSupplierReservationResponse < AgencyCommand
  include ReservationCommandSupport

  # Independently appendable capacity events from a Reservation response.
  # Lineage-based types (reinstated, corrections) are out of scope for this form.
  CAPACITY_CONSEQUENCE_EVENT_TYPES = %w[increased released withdrawn].freeze

  def initialize(agency:, actor:, reservation:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      booking_supplier, departure, arrangement, version, reservation, revision =
        lock_reservation_mutation_graph!(@reservation, revision_status: "requested")
      raise Error.new("That reservation has no requested revision to respond to.", code: :invalid_state) if revision.nil?

      validate_response_state!(departure, arrangement, version)

      # Digest-before-pending: replay must succeed even when some submitted scopes
      # were already resolved by the original command.
      if (replay = replay_response_if_claimed!(key, reservation, revision))
        return replay
      end

      latest = latest_outcomes_by_scope(revision)
      pending = revision.scopes.lock.order(:position, :id).select { |scope| latest[scope.id]&.requested? }
      if pending.empty?
        raise Error.new("There are no pending requested scopes to respond to.", code: :invalid_state)
      end

      scopes = selected_pending_scopes_from(pending)
      outcomes = normalize_outcomes!(scopes)
      payload = response_payload(reservation, revision, outcomes)

      record_response_already_locked!(
        booking_supplier: booking_supplier,
        departure: departure,
        arrangement: arrangement,
        version: version,
        reservation: reservation,
        revision: revision,
        scopes: scopes,
        outcomes: outcomes,
        key: key,
        payload: payload,
        audit: true
      )
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  def replay_response_if_claimed!(key, reservation, revision)
    lock_idempotency_slot!(self.class.name, key)
    existing = @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
    return nil unless existing

    event = reservation.events.find_by(
      id: existing.result_record_id,
      agency_id: @agency.id,
      supplier_reservation_revision_id: revision.id,
      event_kind: "response"
    )
    unless event
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    scopes = event.scope_outcomes
      .includes(:supplier_reservation_scope)
      .map(&:supplier_reservation_scope)
      .uniq
      .sort_by { |scope| [ scope.position, scope.id ] }
    outcomes = normalize_outcomes!(scopes)
    payload = response_payload(reservation, revision, outcomes)
    unless existing.payload_digest == payload_digest(payload)
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(status: :replayed, record: event)
  end

  # Caller must already hold the Reservation mutation lock graph and requested revision.
  def record_response_already_locked!(
    booking_supplier:, departure:, arrangement:, version:, reservation:, revision:,
    scopes:, outcomes:, key: nil, payload: nil, audit: true
  )
    validate_response_state!(departure, arrangement, version)

    now = Time.current
    event = SupplierReservationEvent.new(
      event_owner(reservation, revision, version).merge(
        event_kind: "response",
        occurred_at: normalize_occurred_at(@attributes[:occurred_at]) || now,
        recorded_at: now,
        actor: @actor,
        channel: @attributes[:channel].to_s.strip,
        reference_note: @attributes[:reference_note].to_s.strip,
        scope_fingerprint: scope_fingerprint(scopes)
      )
    )
    if key && payload
      key_record = claim_reservation_idempotency!(key, payload, event)
      event.agency_command_idempotency_key = key_record
    end
    event.save!

    confirmation = nil
    confirmed_outcomes = outcomes.select { |entry| entry[:outcome_kind] == "confirmed" }
    if confirmed_outcomes.any?
      confirmation = resolve_confirmation!(
        arrangement: arrangement,
        version: version,
        reservation: reservation,
        booking_supplier: booking_supplier,
        recorded_at: now
      )
      link_response!(confirmation, reservation, revision, event, version)
    end

    capacity_events = []
    confirmed_entries = []
    outcomes.each do |entry|
      scope = entry[:scope]
      outcome = event.scope_outcomes.create!(
        outcome_owner(scope, event).merge(
          outcome_kind: entry[:outcome_kind],
          quantity: entry[:quantity],
          quantity_basis: entry[:quantity_basis],
          supplier_note: entry[:supplier_note],
          decline_reason: entry[:decline_reason]
        )
      )
      next unless confirmation && entry[:outcome_kind] == "confirmed"

      SupplierConfirmationReservationScopeLink.create!(
        owner_attributes(arrangement, version).merge(
          supplier_confirmation: confirmation,
          supplier_reservation: reservation,
          supplier_reservation_revision: revision,
          supplier_reservation_scope: scope
        )
      )
      confirmed_entries << { scope: scope, quantity: outcome.quantity }
    end

    if confirmation && confirmed_entries.any?
      capacity_events = apply_capacity_consequences!(
        confirmation: confirmation,
        arrangement: arrangement,
        version: version,
        confirmed_scopes: confirmed_entries.map { |entry| entry[:scope] },
        recorded_at: now
      )
      open_reservation_commitments_once!(
        confirmation: confirmation,
        version: version,
        reservation: reservation,
        revision: revision,
        event: event,
        confirmed_entries: confirmed_entries
      )
    end

    rebuild_reservation_projection_already_locked!(reservation)
    if audit
      audit!(
        agency: @agency, action: "supplier_reservation.response_recorded", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "supplier_reservation_event_id" => event.id,
          "supplier_confirmation_id" => confirmation&.id,
          "capacity_event_ids" => capacity_events.map(&:id),
          "outcome_kinds" => outcomes.map { |entry| entry[:outcome_kind] }
        }
      )
    end
    Result.new(status: :created, record: event)
  end

  private

  def validate_response_state!(departure, arrangement, version)
    unless departure.active? || departure.departed?
      raise Error.new("That departure cannot record reservation responses.", code: :invalid_state)
    end
    unless arrangement.active? && (version.activated? || version.superseded?)
      raise Error.new("Responses require the reservation's exact activated version.", code: :invalid_state)
    end
  end

  def selected_pending_scopes(revision)
    latest = latest_outcomes_by_scope(revision)
    pending = revision.scopes.lock.order(:position, :id).select { |scope| latest[scope.id]&.requested? }
    raise Error.new("There are no pending requested scopes to respond to.", code: :invalid_state) if pending.empty?

    selected_pending_scopes_from(pending)
  end

  def selected_pending_scopes_from(pending)
    requested_ids = Array(@attributes[:scope_ids]).presence
    return pending if requested_ids.blank?

    selected = pending.select { |scope| requested_ids.map(&:to_s).include?(scope.id) }
    if selected.size != requested_ids.uniq.size
      raise Error.new("Choose only pending requested scopes for this response.", code: :invalid)
    end
    selected
  end

  def normalize_outcomes!(scopes)
    raw = @attributes[:outcomes]
    by_scope = if raw.respond_to?(:to_h)
      raw.to_h.with_indifferent_access
    else
      {}
    end

    scopes.map do |scope|
      attrs = (by_scope[scope.id] || by_scope[scope.id.to_s] || @attributes).to_h.with_indifferent_access
      kind = attrs[:outcome_kind].to_s.strip
      unless %w[confirmed declined counterproposed].include?(kind)
        raise Error.new("Choose confirmed, declined, or counterproposed for each scope.", code: :invalid)
      end
      quantity = normalize_optional_positive_integer(attrs[:quantity], "Confirmed quantity")
      basis = attrs[:quantity_basis].to_s.strip.presence || (quantity && scope.quantity_basis)
      if quantity.present? && kind != "confirmed"
        raise Error.new("Only confirmed outcomes may carry quantity.", code: :invalid)
      end
      if quantity.present?
        unless SupplierReservationScope::QUANTITY_BASES.include?(basis)
          raise Error.new("Choose a valid confirmed quantity basis.", code: :invalid)
        end
      elsif basis.present?
        raise Error.new("Quantity basis requires a quantity.", code: :invalid)
      end
      decline_reason = attrs[:decline_reason].to_s.strip.presence
      if kind == "declined" && decline_reason.blank?
        raise Error.new("Enter a decline reason.", code: :invalid)
      end
      if kind != "declined" && decline_reason.present?
        raise Error.new("Decline reason is only valid for declined outcomes.", code: :invalid)
      end
      {
        scope: scope,
        outcome_kind: kind,
        quantity: quantity,
        quantity_basis: basis,
        supplier_note: attrs[:supplier_note].to_s.strip.presence,
        decline_reason: decline_reason
      }
    end
  end

  def resolve_confirmation!(arrangement:, version:, reservation:, booking_supplier:, recorded_at:)
    if @attributes[:existing_confirmation_id].present?
      confirmation = SupplierConfirmation.where(agency_id: @agency.id)
        .lock.find_by(id: @attributes[:existing_confirmation_id])
      raise ActiveRecord::RecordNotFound unless confirmation
      ensure_confirmation_compatible!(confirmation, arrangement, version, booking_supplier)
      return confirmation
    end

    attrs = normalized_confirmation_attributes
    confirmation = SupplierConfirmation.create!(
      owner_attributes(arrangement, version).merge(
        confirming_supplier_id: booking_supplier.id,
        actor: @actor,
        recorded_at: recorded_at,
        **attrs
      )
    )
    if (identifier = resolve_identifier!(confirmation, arrangement, reservation, booking_supplier))
      SupplierConfirmationIdentifierLink.create!(
        owner_attributes(arrangement, version).merge(
          supplier_confirmation: confirmation,
          supplier_issued_identifier: identifier
        )
      )
    end
    confirmation
  end

  def normalized_confirmation_attributes
    evidence = (@attributes[:evidence] || @attributes).to_h.with_indifferent_access
    kind = evidence[:evidence_kind].to_s.strip
    unless SupplierConfirmation::EVIDENCE_KINDS.include?(kind)
      raise Error.new("Choose valid Supplier confirmation evidence.", code: :invalid)
    end
    other_label = evidence[:other_evidence_label].to_s.strip.presence
    if (kind == "other") != other_label.present?
      raise Error.new("Enter an other evidence label only for other evidence.", code: :invalid)
    end
    evidence_on = parse_date(evidence[:evidence_on], "Evidence date")
    channel = evidence[:channel].to_s.strip.presence || @attributes[:channel].to_s.strip
    note = evidence[:reference_note].to_s.strip.presence || @attributes[:reference_note].to_s.strip
    reason = evidence[:confirmed_without_identifier_reason].to_s.strip.presence
    if evidence_on.blank? || channel.blank? || note.blank?
      raise Error.new("Enter complete Supplier confirmation evidence.", code: :invalid)
    end
    identifier = (@attributes[:identifier] || {}).to_h
    if identifier.blank? && reason.blank?
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

  def ensure_confirmation_compatible!(confirmation, arrangement, version, booking_supplier)
    compatible = confirmation.agency_id == @agency.id &&
      confirmation.departure_id == arrangement.departure_id &&
      confirmation.supplier_arrangement_id == arrangement.id &&
      confirmation.supplier_arrangement_version_id == version.id &&
      confirmation.confirming_supplier_id == booking_supplier.id
    unless compatible
      raise Error.new("That confirmation is not compatible with this reservation.", code: :invalid)
    end
  end

  def resolve_identifier!(confirmation, arrangement, reservation, booking_supplier)
    attrs = (@attributes[:identifier] || {}).to_h.with_indifferent_access
    return if attrs.blank?

    type = attrs[:identifier_type].to_s.strip
    unless SupplierIssuedIdentifier::IDENTIFIER_TYPES.include?(type)
      raise Error.new("Choose a valid Supplier identifier type.", code: :invalid)
    end
    display = attrs[:display_value].to_s.strip
    normalized = display.downcase
    issuer = attrs[:issuer_context].to_s.strip
    other_label = attrs[:other_type_label].to_s.strip.presence
    if display.blank? || issuer.blank? || ((type == "other") != other_label.present?)
      raise Error.new("Enter a complete qualified Supplier identifier.", code: :invalid)
    end
    lookup = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: booking_supplier.id,
      identifier_type: type,
      issuer_context: issuer,
      normalized_value: normalized,
      arrangement: arrangement,
      reservation: reservation
    )
    if lookup.foreign.any?
      acknowledge_identifier_duplicate!(
        lookup.foreign,
        fingerprint_fields: {
          supplier_id: booking_supplier.id,
          identifier_type: type,
          issuer_context: issuer,
          normalized_value: normalized
        }
      )
    end
    lookup.same_owner.first ||
      SupplierIssuedIdentifier.create!(
        agency: @agency, departure_id: arrangement.departure_id,
        supplier_arrangement: arrangement,
        supplier_reservation: reservation,
        supplier_id: booking_supplier.id,
        issuer_context: issuer, identifier_type: type,
        other_type_label: other_label, display_value: display,
        normalized_value: normalized, first_supplier_confirmation: confirmation
      )
  end

  def acknowledge_identifier_duplicate!(foreign_rows, fingerprint_fields:)
    fingerprint = DuplicateAcknowledgement.fingerprint(fingerprint_fields)
    candidates = foreign_rows.map do |row|
      OpenStruct.new(id: row.id, signals: [ "supplier_issued_identifier", row.display_value ])
    end
    candidate_digest = DuplicateAcknowledgement.candidate_digest(candidates)
    token = @attributes[:duplicate_acknowledgement_token].presence ||
      @attributes[:acknowledgement_token].presence
    if token.blank?
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
      token, agency: @agency, actor: @actor, command: "supplier_issued_identifier.create"
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

  def link_response!(confirmation, reservation, revision, event, version)
    SupplierConfirmationReservationResponseLink.create!(
      owner_attributes(confirmation.supplier_arrangement, version).merge(
        supplier_confirmation: confirmation,
        supplier_reservation: reservation,
        supplier_reservation_revision: revision,
        supplier_reservation_event: event
      )
    )
  end

  def apply_capacity_consequences!(confirmation:, arrangement:, version:, confirmed_scopes:, recorded_at:)
    consequences = Array(@attributes[:capacity_consequences]).presence ||
      Array((@attributes[:capacity_consequence].presence && [ @attributes[:capacity_consequence] ]))
    return [] if consequences.blank?

    confirmed_ids = confirmed_scopes.map { |scope| scope.id.to_s }
    consequences.filter_map do |raw|
      attrs = raw.to_h.with_indifferent_access
      next if attrs.values.all?(&:blank?)

      pool_id = attrs[:capacity_pool_id].presence
      event_type = attrs[:event_type].to_s.strip.presence
      quantity = attrs[:quantity]
      effective_on = attrs[:effective_on]
      scope_id = attrs[:supplier_reservation_scope_id].presence

      if pool_id.blank?
        raise Error.new(
          "Choose a Capacity Pool for each capacity consequence, or clear the other fields.",
          code: :invalid
        )
      end
      if event_type.blank? || quantity.blank? || effective_on.blank?
        raise Error.new(
          "Enter event type, quantity, and effective date for each capacity consequence.",
          code: :invalid
        )
      end
      unless CAPACITY_CONSEQUENCE_EVENT_TYPES.include?(event_type)
        raise Error.new(
          "Choose increased, released, or withdrawn for a Reservation capacity consequence.",
          code: :invalid
        )
      end
      if scope_id.present? && !confirmed_ids.include?(scope_id.to_s)
        raise Error.new(
          "Capacity consequence scope must be one of the confirmed scopes on this response.",
          code: :invalid
        )
      end

      pool = arrangement.capacity_pools.lock.find(pool_id)
      unless pool.supplying_supplier_id == confirmation.confirming_supplier_id
        raise Error.new(
          "Capacity consequence Pool must be supplied by the confirming Supplier.",
          code: :invalid
        )
      end
      if scope_id.present?
        scope = confirmed_scopes.find { |row| row.id.to_s == scope_id.to_s }
        unless capacity_pool_compatible_with_scope?(pool, scope)
          raise Error.new(
            "Capacity consequence Pool is not compatible with the confirmed scope.",
            code: :invalid
          )
        end
      end

      event = AppendCapacityEventAlreadyLocked.new(
        pool: pool,
        actor: @actor,
        event_type: event_type,
        quantity: Integer(quantity),
        effective_on: parse_date(effective_on, "Capacity effective date"),
        recorded_at: recorded_at,
        version: version,
        evidence: attrs[:evidence] || {
          evidence_kind: confirmation.evidence_kind,
          evidence_on: confirmation.evidence_on,
          evidence_reference_note: confirmation.reference_note
        }
      ).call
      SupplierConfirmationCapacityEventLink.create!(
        owner_attributes(arrangement, version).merge(
          supplier_confirmation: confirmation,
          capacity_event: event
        )
      )
      event
    rescue ArgumentError, TypeError
      raise Error.new("Capacity consequence quantity must be a positive whole number.", code: :invalid)
    end
  end

  def capacity_pool_compatible_with_scope?(pool, scope)
    return true if scope.nil?
    return pool.id == scope.capacity_pool_id if scope.target_kind == "capacity_pool"

    (scope.arrangement_item_id.blank? || pool.arrangement_item_id == scope.arrangement_item_id) &&
      (scope.service_occurrence_id.blank? || pool.service_occurrence_id == scope.service_occurrence_id) &&
      (scope.supplier_resource_id.blank? || pool.supplier_resource_id == scope.supplier_resource_id)
  end

  def open_reservation_commitments_once!(confirmation:, version:, reservation:, revision:, event:, confirmed_entries:)
    version.supplier_commitment_trigger_definitions
      .where(trigger_kind: "reservation_confirmation").order(:position, :id).each do |trigger|
      next unless trigger.committed_supplier_id == confirmation.confirming_supplier_id

      covering = confirmed_entries.select { |entry| trigger_matches_scope?(trigger, entry[:scope]) }
      next if covering.empty?

      coverage_scope = resolve_coverage_scope!(trigger, covering)
      quantity = confirmed_quantity_for(trigger, covering, coverage_scope)
      amount = confirmed_amount_for(trigger)

      OpenSupplierCommitmentAlreadyLocked.new(
        trigger: trigger,
        confirmation: confirmation,
        actor: @actor,
        reservation: reservation,
        revision: revision,
        scope: coverage_scope,
        response_event: event,
        confirmed_quantity: quantity,
        confirmed_amount_minor_units: amount,
        allow_unresolved: true
      ).call
    end
  end

  def resolve_coverage_scope!(trigger, covering)
    if covering.size == 1
      return covering.first[:scope]
    end

    coverage_id = coverage_scope_id_for(trigger)
    if coverage_id.blank?
      raise Error.new(
        "Choose which confirmed scope covers this Arrangement-wide commitment trigger.",
        code: :invalid
      )
    end
    selected = covering.find { |entry| entry[:scope].id.to_s == coverage_id.to_s }
    unless selected
      raise Error.new(
        "Coverage scope must be one of the confirmed scopes for this trigger.",
        code: :invalid
      )
    end
    selected[:scope]
  end

  def coverage_scope_id_for(trigger)
    keyed = (@attributes[:coverage_scope_ids] || {}).to_h.with_indifferent_access
    keyed[trigger.id].presence || keyed[trigger.id.to_s].presence || @attributes[:coverage_scope_id].presence
  end

  def confirmed_quantity_for(trigger, covering, coverage_scope)
    keyed = (@attributes[:confirmed_quantities] || {}).to_h.with_indifferent_access
    keyed_value = keyed[trigger.id].presence || keyed[trigger.id.to_s].presence
    return keyed_value if keyed_value.present?

    entry = covering.find { |row| row[:scope].id == coverage_scope.id } || covering.first
    entry[:quantity]
  end

  def confirmed_amount_for(trigger)
    keyed = (@attributes[:confirmed_amounts_minor_units] || {}).to_h.with_indifferent_access
    keyed[trigger.id].presence || keyed[trigger.id.to_s].presence ||
      @attributes[:confirmed_amount_minor_units]
  end

  def trigger_matches_scope?(trigger, scope)
    return true if trigger.arrangement_item_id.blank? && trigger.service_occurrence_id.blank? &&
      trigger.supplier_resource_id.blank? && trigger.capacity_pool_id.blank?

    (trigger.arrangement_item_id.blank? || trigger.arrangement_item_id == scope.arrangement_item_id) &&
      (trigger.service_occurrence_id.blank? || trigger.service_occurrence_id == scope.service_occurrence_id) &&
      (trigger.supplier_resource_id.blank? || trigger.supplier_resource_id == scope.supplier_resource_id) &&
      (trigger.capacity_pool_id.blank? || trigger.capacity_pool_id == scope.capacity_pool_id)
  end

  def response_payload(reservation, revision, outcomes)
    {
      reservation_id: reservation.id,
      revision_id: revision.id,
      outcomes: outcomes.map do |entry|
        {
          scope_id: entry[:scope].id,
          outcome_kind: entry[:outcome_kind],
          quantity: entry[:quantity],
          quantity_basis: entry[:quantity_basis],
          decline_reason: entry[:decline_reason],
          supplier_note: entry[:supplier_note]
        }
      end,
      occurred_at: @attributes[:occurred_at].presence,
      confirmed_amount_minor_units: @attributes[:confirmed_amount_minor_units],
      confirmed_amounts_minor_units: @attributes[:confirmed_amounts_minor_units],
      confirmed_quantities: @attributes[:confirmed_quantities],
      coverage_scope_id: @attributes[:coverage_scope_id],
      coverage_scope_ids: @attributes[:coverage_scope_ids],
      channel: @attributes[:channel].to_s.strip,
      reference_note: @attributes[:reference_note].to_s.strip,
      existing_confirmation_id: @attributes[:existing_confirmation_id],
      evidence: @attributes[:evidence],
      identifier: @attributes[:identifier],
      capacity_consequences: @attributes[:capacity_consequences] || @attributes[:capacity_consequence]
    }
  end

  def normalize_occurred_at(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    raise Error.new("Response time is not valid.", code: :invalid)
  end

  def parse_date(value, label)
    return value if value.is_a?(Date)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Error.new("#{label} is not valid.", code: :invalid)
  end

  def event_owner(reservation, revision, version)
    reservation_owner(reservation, version).merge(supplier_reservation_revision: revision)
  end

  def outcome_owner(scope, event)
    {
      agency: @agency,
      departure_id: scope.departure_id,
      supplier_arrangement_id: scope.supplier_arrangement_id,
      supplier_arrangement_version_id: scope.supplier_arrangement_version_id,
      supplier_reservation_id: scope.supplier_reservation_id,
      supplier_reservation_revision_id: scope.supplier_reservation_revision_id,
      supplier_reservation_event: event,
      supplier_reservation_scope: scope
    }
  end

  def owner_attributes(arrangement, version)
    {
      agency: @agency,
      departure_id: arrangement.departure_id,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version
    }
  end
end
