require "test_helper"

class SupplierReservationCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Reservation Supplier")
    @departure = create_capacity_departure(@agency, name: "Reservation Departure")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Reservation",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
  end

  test "create planned reservation records stable identity exact revision scopes projection and audit" do
    key = SecureRandom.uuid

    result = create_reservation(idempotency_key: key)
    reservation = result.record

    assert_equal :created, result.status
    assert_equal @supplier.id, reservation.booking_supplier_id
    assert_equal 1, reservation.revisions.count
    assert_equal 2, reservation.revisions.sole.scopes.count
    assert_equal "planned", reservation.projection.state
    assert_equal 2, reservation.projection.planned_scope_count
    assert_equal 1, AuditEvent.where(
      action: "supplier_reservation.created",
      subject_type: "SupplierReservation",
      subject_id: reservation.id
    ).count

    replay = create_reservation(idempotency_key: key)
    assert_equal :replayed, replay.status
    assert_equal reservation.id, replay.record.id
  end

  test "request requires the exact version to be currently activated" do
    reservation = create_reservation.record

    error = assert_raises(AgencyCommand::Error) { request_reservation(reservation) }
    assert_equal :invalid_state, error.code
    assert_equal "planned", reservation.revisions.sole.status
  end

  test "request records immutable event outcomes and projection with idempotent replay" do
    activate_version_directly
    reservation = create_reservation.record
    key = SecureRandom.uuid

    result = request_reservation(reservation, idempotency_key: key)
    event = result.record

    assert_equal :created, result.status
    assert_equal "request", event.event_kind
    assert_equal "requested", reservation.revisions.sole.reload.status
    assert_equal 2, event.scope_outcomes.count
    assert_equal "requested", reservation.projection.reload.state
    assert_equal 2, reservation.projection.pending_scope_count
    assert_equal 1, AuditEvent.where(
      action: "supplier_reservation.requested",
      subject_type: "SupplierReservation",
      subject_id: reservation.id
    ).count

    assert_no_changes -> { SupplierReservationEvent.count } do
      replay = request_reservation(reservation, idempotency_key: key)
      assert_equal :replayed, replay.status
      assert_equal event.id, replay.record.id
    end
  end

  test "withdrawal affects only pending requested scopes without capacity or financial effects" do
    activate_version_directly
    reservation = create_reservation.record
    request_reservation(reservation)
    scope = reservation.revisions.sole.scopes.order(:position).first

    result = WithdrawSupplierReservation.new(
      agency: @agency,
      actor: @actor,
      reservation: reservation,
      scope_ids: [ scope.id ],
      reason: "Supplier asked us to retract this segment",
      idempotency_key: SecureRandom.uuid
    ).call

    assert_equal :created, result.status
    assert_equal "withdrawal", result.record.event_kind
    projection = reservation.projection.reload
    assert_equal "requested", projection.state
    assert_equal 1, projection.pending_scope_count
    assert_equal 1, projection.withdrawn_scope_count
    assert_equal 0, CapacityEvent.count
    assert_equal 0, SupplierCommitment.count
  end

  private

  def create_reservation(idempotency_key: SecureRandom.uuid)
    CreateSupplierReservation.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      idempotency_key: idempotency_key,
      attributes: {
        booking_supplier_id: @supplier.id,
        scopes: {
          "0" => { target_kind: "arrangement", label: "Whole booking" },
          "1" => {
            target_kind: "occurrence",
            service_occurrence_id: @graph[:occurrence].id,
            requested_quantity: 12,
            quantity_basis: "traveler_positions",
            label: "Arrival service"
          }
        }
      }
    ).call
  end

  def request_reservation(reservation, idempotency_key: SecureRandom.uuid)
    RecordSupplierReservationRequest.new(
      agency: @agency,
      actor: @actor,
      reservation: reservation,
      idempotency_key: idempotency_key,
      attributes: {
        occurred_at: Time.zone.parse("2026-06-01 12:00:00 UTC"),
        channel: "portal",
        reference_note: "Supplier request submitted"
      }
    ).call
  end

  def activate_version_directly
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end
end
