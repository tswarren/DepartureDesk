class UpdatePlannedSupplierReservation < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:, attributes:, revision_lock_version:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @attributes = attributes.to_h.with_indifferent_access
    @revision_lock_version = revision_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      booking_supplier, departure, arrangement, version, reservation, revision =
        lock_reservation_mutation_graph!(@reservation, revision_status: "planned")
      raise Error.new("That reservation does not have one planned revision.", code: :invalid_state) if revision.nil?

      ensure_reservation_planning_state!(departure, arrangement, version, booking_supplier)
      ensure_current_lock_version!(revision, @revision_lock_version)
      scopes = normalize_scopes!(arrangement, version, @attributes[:scopes])

      revision.scopes.lock.order(:position, :id).destroy_all
      scopes.each do |attrs|
        revision.scopes.create!(
          attrs.merge(
            agency: @agency,
            departure: departure,
            supplier_arrangement: arrangement,
            supplier_arrangement_version: version,
            supplier_reservation: reservation
          )
        )
      end
      revision.touch
      rebuild_reservation_projection_already_locked!(reservation)
      audit!(
        agency: @agency, action: "supplier_reservation.updated", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "supplier_arrangement_version_id" => version.id,
          "scope_count" => revision.scopes.count
        }
      )
      Result.new(status: :updated, record: reservation)
    end
  rescue ActiveRecord::SoleRecordExceeded
    raise Error.new("That reservation does not have one planned revision.", code: :invalid_state)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
