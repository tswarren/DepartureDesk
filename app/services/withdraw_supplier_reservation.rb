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
      _booking_supplier, _departure, _arrangement, version, reservation, revision =
        lock_reservation_mutation_graph!(@reservation, revision_status: "requested")
      raise Error.new("That reservation has no requested revision.", code: :invalid_state) unless revision

      all_scopes = revision.scopes.lock.order(:position, :id).to_a
      selected = selected_pending_scopes!(revision, all_scopes)
      payload = {
        reservation_id: reservation.id,
        revision_id: revision.id,
        scope_ids: selected.map(&:id),
        reason: reason
      }
      if (replay = replay_reservation_idempotency(key, payload, SupplierReservationEvent))
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
      key_record = claim_reservation_idempotency!(key, payload, event)
      event.agency_command_idempotency_key = key_record
      event.save!
      selected.each do |scope|
        create_scope_outcome!(event, scope, outcome_kind: "withdrawn")
      end
      rebuild_reservation_projection_already_locked!(reservation)
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
end
