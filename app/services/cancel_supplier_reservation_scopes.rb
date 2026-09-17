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
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      arrangement = @agency.supplier_arrangements.lock.find(reservation.supplier_arrangement_id)
      @agency.departures.lock.find(reservation.departure_id)
      lock_idempotency_slot!(self.class.name, key)
      if (existing = existing_idempotency(key))
        return Result.new(status: :replayed, record: SupplierReservationEvent.find(existing.result_record_id))
      end

      revision = reservation.revisions.lock.where(status: "requested").order(revision_number: :desc).first
      raise Error.new("That reservation has no requested revision.", code: :invalid_state) if revision.nil?

      version = arrangement.versions.lock.find(revision.supplier_arrangement_version_id)
      scopes = confirmed_scopes(revision)
      raise Error.new("Choose previously confirmed scopes to cancel.", code: :invalid) if scopes.empty?

      payload = {
        reservation_id: reservation.id,
        revision_id: revision.id,
        scope_ids: scopes.map(&:id),
        reason: reason
      }
      if (existing = existing_idempotency(key))
        unless existing.payload_digest == payload_digest(payload)
          raise Error.new("That idempotency key was already used for different input.", code: :conflict)
        end
        return Result.new(status: :replayed, record: SupplierReservationEvent.find(existing.result_record_id))
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
      key_record = AgencyCommandIdempotencyKey.create!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: key,
        payload_digest: payload_digest(payload),
        result_record_type: SupplierReservationEvent.name,
        result_record_id: event.id
      )
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
      RebuildSupplierReservationProjection.new(
        agency: @agency, actor: @actor, reservation: reservation
      ).call
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
    selected = revision.scopes.lock.order(:position, :id).select do |scope|
      latest[scope.id]&.confirmed? && (@scope_ids.blank? || @scope_ids.map(&:to_s).include?(scope.id))
    end
    selected
  end

  def existing_idempotency(key)
    @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
  end
end
