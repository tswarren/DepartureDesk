require "test_helper"

class UnresolvedReservationCommitmentTriggersTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Unresolved Supplier")
    @departure = create_capacity_departure(@agency, name: "Unresolved Departure")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Unresolved", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @item_trigger = SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      trigger_kind: "reservation_confirmation",
      authority_shape: "confirmed_amount",
      committed_supplier: @supplier,
      arrangement_item: @graph[:item],
      description: "Item deposit",
      currency: @departure.operating_currency,
      position: 1
    )
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  test "scopes from another reservation do not make triggers unresolved for this reservation" do
    reservation_a = create_and_request_reservation(
      scopes: [ {
        target_kind: "item",
        arrangement_item_id: @graph[:item].id,
        label: "Item A"
      } ]
    )
    reservation_b = create_and_request_reservation(
      scopes: [ { target_kind: "arrangement", label: "Whole B" } ]
    )

    respond_confirmed(reservation_a)
    confirmation = SupplierConfirmationReservationResponseLink
      .find_by!(supplier_reservation_id: reservation_a.id).supplier_confirmation

    # Reuse confirmation evidence on reservation B (arrangement scope only).
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation_b,
      attributes: {
        channel: "portal",
        reference_note: "Reuse",
        existing_confirmation_id: confirmation.id,
        outcomes: reservation_b.revisions.where(status: "requested").sole.scopes.map { |scope|
          [ scope.id, { outcome_kind: "confirmed" } ]
        }.to_h
      },
      idempotency_key: SecureRandom.uuid
    ).call

    unresolved_b = UnresolvedReservationCommitmentTriggers.call(
      agency: @agency, reservation: reservation_b
    )
    assert unresolved_b.none? { |row| row.trigger.id == @item_trigger.id }

    unresolved_a = UnresolvedReservationCommitmentTriggers.call(
      agency: @agency, reservation: reservation_a
    )
    assert unresolved_a.any? { |row| row.trigger.id == @item_trigger.id }
  end

  test "duplicate response links for the same reservation revision are deduplicated" do
    reservation = create_and_request_reservation(
      scopes: [ {
        target_kind: "item",
        arrangement_item_id: @graph[:item].id,
        label: "Item"
      } ]
    )
    respond_confirmed(reservation)
    link = SupplierConfirmationReservationResponseLink.find_by!(supplier_reservation_id: reservation.id)
    second_event = SupplierReservationEvent.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_reservation: reservation,
      supplier_reservation_revision: link.supplier_reservation_revision,
      event_kind: "response",
      occurred_at: Time.current,
      recorded_at: Time.current,
      actor: @actor,
      channel: "portal",
      reference_note: "Second link fixture",
      scope_fingerprint: "fixture"
    )
    SupplierConfirmationReservationResponseLink.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_confirmation: link.supplier_confirmation,
      supplier_reservation: reservation,
      supplier_reservation_revision: link.supplier_reservation_revision,
      supplier_reservation_event: second_event
    )

    unresolved = UnresolvedReservationCommitmentTriggers.call(agency: @agency, reservation: reservation)
    matching = unresolved.select { |row| row.trigger.id == @item_trigger.id }
    assert_equal 1, matching.size
  end

  private

  def create_and_request_reservation(scopes:)
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: scopes
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
    reservation
  end

  def respond_confirmed(reservation)
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: {
        channel: "portal",
        reference_note: "Confirmed",
        outcomes: reservation.revisions.where(status: "requested").sole.scopes.map { |scope|
          [ scope.id, { outcome_kind: "confirmed" } ]
        }.to_h,
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed",
          confirmed_without_identifier_reason: "Later"
        }
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end
end
