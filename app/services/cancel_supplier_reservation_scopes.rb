class CancelSupplierReservationScopes < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:, scope_ids:, reason:, idempotency_key:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @scope_ids = Array(scope_ids)
    @reason = reason
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)
    reason = @reason.to_s.strip
    raise Error.new("Enter a cancellation reason.", code: :invalid) if reason.blank?

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      _booking_supplier, _departure, _arrangement, version, reservation, revision =
        lock_reservation_mutation_graph!(@reservation, revision_status: "requested")
      raise Error.new("That reservation has no requested revision.", code: :invalid_state) if revision.nil?

      scopes = confirmed_scopes(revision)
      raise Error.new("Choose previously confirmed scopes to cancel.", code: :invalid) if scopes.empty?

      payload = {
        reservation_id: reservation.id,
        revision_id: revision.id,
        scope_ids: scopes.map(&:id),
        reason: reason
      }
      if (replay = replay_reservation_idempotency(key, payload, SupplierReservationEvent))
        return replay
      end

      now = Time.current
      event = SupplierReservationEvent.new(
        reservation_owner(reservation, version).merge(
          supplier_reservation_revision: revision,
          event_kind: "cancellation",
          occurred_at: now,
          recorded_at: now,
          actor: @actor,
          reason: reason,
          scope_fingerprint: scope_fingerprint(scopes)
        )
      )
      key_record = claim_reservation_idempotency!(key, payload, event)
      event.agency_command_idempotency_key = key_record
      event.save!
      scopes.each do |scope|
        event.scope_outcomes.create!(
          agency: @agency,
          departure_id: scope.departure_id,
          supplier_arrangement_id: scope.supplier_arrangement_id,
          supplier_arrangement_version_id: scope.supplier_arrangement_version_id,
          supplier_reservation_id: scope.supplier_reservation_id,
          supplier_reservation_revision_id: scope.supplier_reservation_revision_id,
          supplier_reservation_event: event,
          supplier_reservation_scope: scope,
          outcome_kind: "cancelled"
        )
      end
      rebuild_reservation_projection_already_locked!(reservation)
      audit!(
        agency: @agency, action: "supplier_reservation.scopes_cancelled", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_event_id" => event.id,
          "scope_ids" => scopes.map(&:id)
        }
      )
      Result.new(status: :created, record: event)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def confirmed_scopes(revision)
    latest = latest_outcomes_by_scope(revision)
    revision.scopes.lock.order(:position, :id).select do |scope|
      latest[scope.id]&.confirmed? && (@scope_ids.blank? || @scope_ids.map(&:to_s).include?(scope.id))
    end
  end
end
