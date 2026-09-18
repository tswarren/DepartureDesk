require "test_helper"

class SupplierReservationConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Reservation Constraint Supplier")
    @departure = create_capacity_departure(@agency, name: "Reservation Constraint")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Reservation constraint",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @reservation = SupplierReservation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      booking_supplier: @supplier
    )
    @revision = @reservation.revisions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, revision_number: 1, status: "planned",
      actor: @actor
    )
  end

  test "database enforces reservation scope target shape" do
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservationScope.insert_all!([
        base_scope.merge(
          id: SecureRandom.uuid_v7,
          position: 1,
          target_kind: "arrangement",
          arrangement_item_id: @graph[:item].id
        )
      ])
    end
  end

  test "database enforces one planned revision per reservation" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      @reservation.revisions.create!(
        agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
        supplier_arrangement_version: @version, revision_number: 2, status: "planned",
        actor: @actor
      )
    end
  end

  test "reservation events and outcomes are append only" do
    scope = @revision.scopes.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_reservation: @reservation,
      position: 1, target_kind: "arrangement"
    )
    event = @revision.events.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_reservation: @reservation,
      event_kind: "request", occurred_at: Time.current, recorded_at: Time.current,
      actor: @actor, channel: "portal", reference_note: "Requested"
    )
    outcome = event.scope_outcomes.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, supplier_reservation: @reservation,
      supplier_reservation_revision: @revision, supplier_reservation_scope: scope,
      outcome_kind: "requested"
    )

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      event.update!(reference_note: "Changed")
    end
    assert_not outcome.destroy
  end

  test "database rejects scope insert on a requested revision" do
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
    revision = reservation.revisions.where(status: "requested").sole

    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservationScope.transaction(requires_new: true) do
        SupplierReservationScope.insert_all!([
          {
            id: SecureRandom.uuid_v7,
            agency_id: @agency.id,
            departure_id: @departure.id,
            supplier_arrangement_id: @arrangement.id,
            supplier_arrangement_version_id: @version.id,
            supplier_reservation_id: reservation.id,
            supplier_reservation_revision_id: revision.id,
            position: 2,
            target_kind: "arrangement",
            label: "Smuggled",
            created_at: Time.current,
            updated_at: Time.current
          }
        ])
      end
    end
    assert_match(/requested reservation scopes are immutable/i, error.message)
    assert_equal 1, revision.scopes.count
  end

  private

  def base_scope
    {
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: @version.id,
      supplier_reservation_id: @reservation.id,
      supplier_reservation_revision_id: @revision.id,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end
