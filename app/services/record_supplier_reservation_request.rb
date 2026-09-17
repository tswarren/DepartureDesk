class RecordSupplierReservationRequest < AgencyCommand
  include ReservationCommandSupport

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
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      arrangement = @agency.supplier_arrangements.lock.find(reservation.supplier_arrangement_id)
      departure = @agency.departures.lock.find(reservation.departure_id)
      lock_idempotency_slot!(self.class.name, key)
      if (existing = existing_idempotency(key))
        return Result.new(status: :replayed, record: SupplierReservationEvent.find(existing.result_record_id))
      end
      revision = reservation.revisions.lock.where(status: "planned").sole
      version = arrangement.versions.lock.find(revision.supplier_arrangement_version_id)
      scopes = revision.scopes.lock.order(:position, :id).to_a
      validate_request_state!(departure, arrangement, version, scopes)
      payload = request_payload(reservation, revision, scopes)
      if (replay = replay_idempotency(key, payload))
        return replay
      end

      now = Time.current
      event = SupplierReservationEvent.new(
        event_owner(reservation, revision, version).merge(
          event_kind: "request",
          occurred_at: normalize_occurred_at(@attributes[:occurred_at]) || now,
          recorded_at: now,
          actor: @actor,
          supplier_contact: resolve_contact(reservation, @attributes[:supplier_contact_id]),
          channel: @attributes[:channel].to_s.strip,
          safe_contact_snapshot: @attributes[:safe_contact_snapshot].to_s.strip.presence,
          reference_note: @attributes[:reference_note].to_s.strip,
          scope_fingerprint: scope_fingerprint(scopes)
        )
      )
      key_record = claim_idempotency!(key, payload, event)
      event.agency_command_idempotency_key = key_record
      event.save!
      scopes.each do |scope|
        event.scope_outcomes.create!(
          outcome_owner(scope, event).merge(outcome_kind: "requested")
        )
      end
      reservation.revisions.where(status: "requested").where.not(id: revision.id).find_each do |older|
        older.update!(status: "superseded")
      end
      revision.update!(status: "requested", requested_at: event.occurred_at)
      RebuildSupplierReservationProjection.new(
        agency: @agency, actor: @actor, reservation: reservation
      ).call
      audit!(
        agency: @agency, action: "supplier_reservation.requested", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "supplier_reservation_event_id" => event.id,
          "scope_count" => scopes.size
        }
      )
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::SoleRecordExceeded
    raise Error.new("That reservation does not have one planned revision.", code: :invalid_state)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def validate_request_state!(departure, arrangement, version, scopes)
    raise Error.new("Add at least one reservation scope before requesting.", code: :invalid) if scopes.empty?
    unless departure.active?
      raise Error.new("Only active departures can record reservation requests.", code: :invalid_state)
    end
    unless arrangement.active? && arrangement.governing_version_id == version.id && version.activated?
      raise Error.new("A reservation can only be requested after its exact version is activated.", code: :invalid_state)
    end
  end

  def request_payload(reservation, revision, scopes)
    {
      reservation_id: reservation.id,
      revision_id: revision.id,
      scope_ids: scopes.map(&:id),
      occurred_at: @attributes[:occurred_at].presence,
      supplier_contact_id: @attributes[:supplier_contact_id].presence,
      channel: @attributes[:channel].to_s.strip,
      safe_contact_snapshot: @attributes[:safe_contact_snapshot].to_s.strip,
      reference_note: @attributes[:reference_note].to_s.strip
    }
  end

  def replay_idempotency(key, payload)
    lock_idempotency_slot!(self.class.name, key)
    existing = existing_idempotency(key)
    return unless existing
    unless existing.payload_digest == payload_digest(payload)
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(status: :replayed, record: SupplierReservationEvent.find(existing.result_record_id))
  end

  def existing_idempotency(key)
    @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
  end

  def claim_idempotency!(key, payload, event)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: self.class.name,
      idempotency_key: key,
      payload_digest: payload_digest(payload),
      result_record_type: SupplierReservationEvent.name,
      result_record_id: event.id
    )
  end

  def normalize_occurred_at(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    raise Error.new("Sent time is not valid.", code: :invalid)
  end

  def resolve_contact(reservation, id)
    uuid = parse_optional_uuid(id, "Supplier contact")
    return if uuid.blank?

    contact = @agency.supplier_contacts.find_by(id: uuid, supplier_id: reservation.booking_supplier_id)
    raise ActiveRecord::RecordNotFound if contact.nil?

    contact
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
end
