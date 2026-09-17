class RebuildSupplierReservationProjection < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:)
    @agency = agency
    @actor = actor
    @reservation = reservation
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      revision = current_revision(reservation)
      attrs = projection_attributes(reservation, revision)
      projection = reservation.projection || reservation.build_projection(
        agency: @agency,
        departure_id: reservation.departure_id,
        supplier_arrangement_id: reservation.supplier_arrangement_id
      )
      projection.assign_attributes(attrs.merge(rebuilt_at: Time.current))
      projection.save!
      Result.new(status: :updated, record: projection)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def current_revision(reservation)
    reservation.revisions.where.not(status: "abandoned").order(revision_number: :desc).first
  end

  def projection_attributes(reservation, revision)
    base = {
      current_revision: revision,
      state: "withdrawn",
      planned_scope_count: 0,
      pending_scope_count: 0,
      confirmed_scope_count: 0,
      counterproposed_scope_count: 0,
      declined_scope_count: 0,
      withdrawn_scope_count: 0,
      cancelled_scope_count: 0
    }
    return base if revision.nil?

    scopes = revision.scopes.order(:position, :id).to_a
    if revision.planned?
      return base.merge(
        state: "planned",
        planned_scope_count: scopes.size
      )
    end

    latest = latest_outcomes_by_scope(revision)
    counts = scopes.each_with_object(Hash.new(0)) do |scope, memo|
      memo[(latest[scope.id]&.outcome_kind || "requested")] += 1
    end
    base.merge(
      state: state_for(counts, scopes.size),
      pending_scope_count: counts["requested"],
      confirmed_scope_count: counts["confirmed"],
      counterproposed_scope_count: counts["counterproposed"],
      declined_scope_count: counts["declined"],
      withdrawn_scope_count: counts["withdrawn"],
      cancelled_scope_count: counts["cancelled"]
    )
  end

  def state_for(counts, scope_count)
    return "confirmed" if scope_count.positive? && counts["confirmed"] == scope_count
    return "declined" if scope_count.positive? && counts["declined"] == scope_count
    return "withdrawn" if scope_count.positive? && counts["withdrawn"] == scope_count
    return "cancelled" if scope_count.positive? && counts["cancelled"] == scope_count
    return "partially_confirmed" if counts["confirmed"].positive? || counts["counterproposed"].positive?

    "requested"
  end
end
