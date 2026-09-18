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
      booking_supplier, departure, arrangement, version = lock_create_reservation_graph!(
        @arrangement,
        @attributes.merge(
          "booking_supplier_id" => @attributes[:booking_supplier_id],
          "supplier_arrangement_version_id" => arrangement_governing_version_id(@arrangement)
        )
      )
      unless departure.active? && arrangement.active? && version.activated?
        raise Error.new("Record existing confirmed bookings only on active Arrangements.", code: :invalid_state)
      end

      scopes = normalize_scopes!(arrangement, version, @attributes[:scopes])
      payload = existing_booking_payload(arrangement, version, booking_supplier, scopes)
      if (replay = replay_reservation_idempotency(key, payload, SupplierReservation))
        return replay
      end

      create_cmd = CreateSupplierReservation.new(
        agency: @agency, actor: @actor, arrangement: arrangement,
        attributes: @attributes, idempotency_key: key
      )
      reservation = create_cmd.create_reservation_already_locked!(
        arrangement: arrangement,
        departure: departure,
        version: version,
        booking_supplier: booking_supplier,
        scopes: scopes,
        audit: false
      )
      revision = reservation.revisions.lock.where(status: "planned").sole
      revision_scopes = revision.scopes.lock.order(:position, :id).to_a

      request_attrs = {
        occurred_at: @attributes[:occurred_at],
        channel: @attributes[:channel],
        reference_note: @attributes[:request_reference_note].presence || @attributes[:reference_note],
        safe_contact_snapshot: @attributes[:safe_contact_snapshot],
        supplier_contact_id: @attributes[:supplier_contact_id]
      }
      request_cmd = RecordSupplierReservationRequest.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: request_attrs, idempotency_key: key
      )
      request_cmd.record_request_already_locked!(
        reservation: reservation,
        revision: revision,
        version: version,
        scopes: revision_scopes,
        departure: departure,
        arrangement: arrangement,
        booking_supplier: booking_supplier,
        audit: false
      )

      revision.reload
      response_attrs = {
        channel: @attributes[:channel],
        reference_note: @attributes[:response_reference_note].presence || @attributes[:reference_note],
        occurred_at: @attributes[:occurred_at],
        evidence: @attributes[:evidence],
        identifier: @attributes[:identifier],
        existing_confirmation_id: @attributes[:existing_confirmation_id],
        capacity_consequence: @attributes[:capacity_consequence],
        confirmed_amount_minor_units: @attributes[:confirmed_amount_minor_units],
        outcomes: revision.scopes.map { |scope|
          [ scope.id, {
            outcome_kind: "confirmed",
            quantity: scope.requested_quantity,
            quantity_basis: scope.quantity_basis
          } ]
        }.to_h
      }
      response_cmd = RecordSupplierReservationResponse.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: response_attrs, idempotency_key: key
      )
      response_cmd.record_response_already_locked!(
        booking_supplier: booking_supplier,
        departure: departure,
        arrangement: arrangement,
        version: version,
        reservation: reservation,
        revision: revision,
        scopes: revision.scopes.lock.order(:position, :id).to_a,
        outcomes: response_cmd.send(:normalize_outcomes!, revision.scopes.lock.order(:position, :id).to_a),
        audit: false
      )

      claim_reservation_idempotency!(key, payload, reservation)
      audit!(
        agency: @agency,
        action: "supplier_reservation.existing_confirmed_recorded",
        subject: reservation,
        actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "booking_supplier_id" => booking_supplier.id,
          "scope_count" => scopes.size
        }
      )
      Result.new(status: :created, record: reservation)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def arrangement_governing_version_id(arrangement_ref)
    unlocked = @agency.supplier_arrangements.find(
      arrangement_ref.respond_to?(:id) ? arrangement_ref.id : arrangement_ref
    )
    unlocked.governing_version_id
  end

  def existing_booking_payload(arrangement, version, booking_supplier, scopes)
    {
      arrangement_id: arrangement.id,
      version_id: version.id,
      booking_supplier_id: booking_supplier.id,
      scopes: scopes,
      occurred_at: @attributes[:occurred_at].presence,
      channel: @attributes[:channel].to_s.strip,
      reference_note: @attributes[:reference_note].to_s.strip,
      request_reference_note: @attributes[:request_reference_note].to_s.strip,
      response_reference_note: @attributes[:response_reference_note].to_s.strip,
      safe_contact_snapshot: @attributes[:safe_contact_snapshot].to_s.strip,
      supplier_contact_id: @attributes[:supplier_contact_id].presence,
      evidence: @attributes[:evidence],
      identifier: @attributes[:identifier],
      existing_confirmation_id: @attributes[:existing_confirmation_id],
      capacity_consequence: @attributes[:capacity_consequence],
      confirmed_amount_minor_units: @attributes[:confirmed_amount_minor_units]
    }
  end
end
