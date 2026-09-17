class WithdrawSupplierReservation < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:, scope_ids:, reason:, idempotency_key:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @scope_ids = Array(scope_ids).reject(&:blank?)
    @reason = reason
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)
    reason = normalize_reason(@reason)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      revision = reservation.revisions.lock.where(status: "requested").order(revision_number: :desc).first
      raise Error.new("That reservation has no requested revision.", code: :invalid_state) unless revision

      version = @agency.supplier_arrangement_versions.lock.find(revision.supplier_arrangement_version_id)
      all_scopes = revision.scopes.lock.order(:position, :id).to_a
      selected = selected_pending_scopes!(revision, all_scopes)
      payload = {
        reservation_id: reservation.id,
        revision_id: revision.id,
        scope_ids: selected.map(&:id),
        reason: reason
      }
      if (replay = replay_idempotency(key, payload))
        return replay
      end

      now = Time.current
      event = SupplierReservationEvent.new(
        reservation_owner(reservation, version).merge(
          supplier_reservation_revision: revision,
          event_kind: "withdrawal",
          occurred_at: now,
          recorded_at: now,
          actor: @actor,
          reason: reason,
          scope_fingerprint: scope_fingerprint(selected)
        )
      )
      key_record = claim_idempotency!(key, payload, event)
      event.agency_command_idempotency_key = key_record
      event.save!
      selected.each do |scope|
        event.scope_outcomes.create!(
          agency: @agency,
          departure_id: scope.departure_id,
          supplier_arrangement_id: scope.supplier_arrangement_id,
          supplier_arrangement_version_id: scope.supplier_arrangement_version_id,
          supplier_reservation_id: scope.supplier_reservation_id,
          supplier_reservation_revision_id: scope.supplier_reservation_revision_id,
          supplier_reservation_event: event,
          supplier_reservation_scope: scope,
          outcome_kind: "withdrawn"
        )
      end
      RebuildSupplierReservationProjection.new(
        agency: @agency, actor: @actor, reservation: reservation
      ).call
      audit!(
        agency: @agency, action: "supplier_reservation.withdrawn", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "supplier_reservation_event_id" => event.id,
          "scope_ids" => selected.map(&:id),
          "reason" => reason
        }
      )
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def selected_pending_scopes!(revision, all_scopes)
    latest = latest_outcomes_by_scope(revision)
    pending = all_scopes.select { |scope| latest[scope.id]&.requested? }
    wanted_ids = @scope_ids.presence || pending.map(&:id)
    selected = all_scopes.select { |scope| wanted_ids.include?(scope.id) }
    if selected.empty? || selected.size != wanted_ids.size
      raise ActiveRecord::RecordNotFound
    end
    unless selected.all? { |scope| latest[scope.id]&.requested? }
      raise Error.new("Only pending requested scopes can be withdrawn.", code: :invalid_state)
    end

    selected
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

    Result.new(status: :replayed, record: SupplierReservationEvent.find(existing.result_record_id))
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
end
