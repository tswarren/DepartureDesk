class RecordExistingConfirmedSupplierReservation < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, arrangement:, attributes:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key || @attributes.delete(:idempotency_key)
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = @agency.supplier_arrangements.lock.find(@arrangement.id)
      departure = @agency.departures.lock.find(arrangement.departure_id)
      unless departure.active? && arrangement.active? && arrangement.governing_version&.activated?
        raise Error.new("Record existing confirmed bookings only on active Arrangements.", code: :invalid_state)
      end
      lock_idempotency_slot!(self.class.name, key)
      if (existing = existing_idempotency(key))
        return Result.new(status: :replayed, record: SupplierReservation.find(existing.result_record_id))
      end

      create_result = CreateSupplierReservation.new(
        agency: @agency,
        actor: @actor,
        arrangement: arrangement,
        attributes: {
          booking_supplier_id: @attributes[:booking_supplier_id],
          supplier_arrangement_version_id: arrangement.governing_version_id,
          scopes: @attributes[:scopes]
        },
        idempotency_key: "#{key}:create"
      ).call
      reservation = create_result.record

      RecordSupplierReservationRequest.new(
        agency: @agency,
        actor: @actor,
        reservation: reservation,
        attributes: {
          occurred_at: @attributes[:occurred_at],
          channel: @attributes[:channel],
          reference_note: @attributes[:request_reference_note].presence || @attributes[:reference_note],
          safe_contact_snapshot: @attributes[:safe_contact_snapshot],
          supplier_contact_id: @attributes[:supplier_contact_id]
        },
        idempotency_key: "#{key}:request"
      ).call

      response_attrs = {
        channel: @attributes[:channel],
        reference_note: @attributes[:response_reference_note].presence || @attributes[:reference_note],
        occurred_at: @attributes[:occurred_at],
        evidence: @attributes[:evidence],
        identifier: @attributes[:identifier],
        existing_confirmation_id: @attributes[:existing_confirmation_id],
        capacity_consequence: @attributes[:capacity_consequence],
        confirmed_amount_minor_units: @attributes[:confirmed_amount_minor_units],
        outcomes: reservation.revisions.where(status: "requested").sole.scopes.map { |scope|
          [ scope.id, { outcome_kind: "confirmed", quantity: scope.requested_quantity, quantity_basis: scope.quantity_basis } ]
        }.to_h
      }
      RecordSupplierReservationResponse.new(
        agency: @agency,
        actor: @actor,
        reservation: reservation,
        attributes: response_attrs,
        idempotency_key: "#{key}:response"
      ).call

      AgencyCommandIdempotencyKey.find_or_create_by!(
        agency: @agency,
        command_name: self.class.name,
        idempotency_key: key
      ) do |record|
        record.payload_digest = payload_digest(@attributes.merge(reservation_id: reservation.id))
        record.result_record_type = SupplierReservation.name
        record.result_record_id = reservation.id
      end

      Result.new(status: create_result.status == :replayed ? :replayed : :created, record: reservation)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def existing_idempotency(key)
    @agency.agency_command_idempotency_keys.where(
      command_name: self.class.name, idempotency_key: key
    ).lock.first
  end
end
