class CreateSupplierReservation < AgencyCommand
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
        @arrangement, @attributes
      )
      ensure_reservation_planning_state!(departure, arrangement, version, booking_supplier)
      scopes = normalize_scopes!(arrangement, version, @attributes[:scopes])
      payload = {
        arrangement_id: arrangement.id,
        version_id: version.id,
        booking_supplier_id: booking_supplier.id,
        scopes: scopes
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: key,
        payload: payload,
        result_class: SupplierReservation
      ) do
        create_reservation_already_locked!(
          arrangement: arrangement,
          departure: departure,
          version: version,
          booking_supplier: booking_supplier,
          scopes: scopes,
          audit: true
        )
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  # Caller must already hold Agency + Supplier → Departure → Arrangement → version locks.
  def create_reservation_already_locked!(arrangement:, departure:, version:, booking_supplier:, scopes:, audit: true)
    reservation = SupplierReservation.create!(
      agency: @agency, departure: departure, supplier_arrangement: arrangement,
      booking_supplier: booking_supplier
    )
    revision = reservation.revisions.create!(
      agency: @agency, departure: departure, supplier_arrangement: arrangement,
      supplier_arrangement_version: version, revision_number: 1, status: "planned",
      actor: @actor
    )
    create_scopes!(revision, scopes)
    rebuild_reservation_projection_already_locked!(reservation)
    audit_reservation!(reservation, revision, "supplier_reservation.created") if audit
    reservation
  end

  private

  def create_scopes!(revision, scopes)
    scopes.each do |attrs|
      revision.scopes.create!(
        attrs.merge(
          agency: @agency,
          departure_id: revision.departure_id,
          supplier_arrangement_id: revision.supplier_arrangement_id,
          supplier_arrangement_version_id: revision.supplier_arrangement_version_id,
          supplier_reservation_id: revision.supplier_reservation_id
        )
      )
    end
  end

  def audit_reservation!(reservation, revision, action)
    audit!(
      agency: @agency, action: action, subject: reservation, actor: @actor,
      details: {
        "supplier_reservation_id" => reservation.id,
        "supplier_reservation_revision_id" => revision.id,
        "supplier_arrangement_id" => reservation.supplier_arrangement_id,
        "supplier_arrangement_version_id" => revision.supplier_arrangement_version_id,
        "booking_supplier_id" => reservation.booking_supplier_id,
        "scope_count" => revision.scopes.count
      }
    )
  end
end
