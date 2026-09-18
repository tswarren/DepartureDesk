require "test_helper"

class SupplierReservationResponseCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Response Supplier")
    @departure = create_capacity_departure(@agency, name: "Response Departure")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Response",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    activate_version_directly
    @reservation = create_reservation.record
    request_reservation(@reservation)
  end

  test "confirmed response creates evidence links projection and blocks ordinary inactivation" do
    key = SecureRandom.uuid
    result = respond_reservation(@reservation, idempotency_key: key)
    event = result.record

    assert_equal :created, result.status
    assert_equal "response", event.event_kind
    assert event.scope_outcomes.all?(&:confirmed?)
    assert_equal "confirmed", @reservation.projection.reload.state
    assert SupplierConfirmationReservationResponseLink.exists?(supplier_reservation_event_id: event.id)
    assert SupplierConfirmationReservationScopeLink.exists?(supplier_reservation_id: @reservation.id)

    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency, actor: agency_users(:harbor_admin), supplier: @supplier,
        status: "inactive", lock_version: @supplier.reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code

    assert_no_changes -> { SupplierReservationEvent.count } do
      replay = respond_reservation(@reservation, idempotency_key: key)
      assert_equal :replayed, replay.status
      assert_equal event.id, replay.record.id
    end
  end

  test "declined response does not create confirmation links" do
    result = respond_reservation(
      @reservation,
      outcomes: @reservation.revisions.sole.scopes.map { |scope|
        [ scope.id, { outcome_kind: "declined", decline_reason: "No allotment" } ]
      }.to_h
    )

    assert_equal :created, result.status
    assert result.record.scope_outcomes.all?(&:declined?)
    assert_equal "declined", @reservation.projection.reload.state
    assert_equal 0, SupplierConfirmationReservationResponseLink.where(supplier_reservation_id: @reservation.id).count
  end

  test "same response key with different note amount or time conflicts" do
    key = SecureRandom.uuid
    respond_reservation(@reservation, idempotency_key: key)

    reservation = create_reservation.record
    request_reservation(reservation)

    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierReservationResponse.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: {
          channel: "portal",
          reference_note: "Confirmed allotment",
          occurred_at: 1.hour.ago,
          confirmed_amount_minor_units: 500_00,
          outcomes: reservation.revisions.where(status: "requested").sole.scopes.map { |scope|
            [ scope.id, { outcome_kind: "confirmed", supplier_note: "Different note" } ]
          }.to_h,
          evidence: {
            evidence_kind: "supplier_confirmation",
            evidence_on: Date.current,
            channel: "portal",
            reference_note: "Confirmed allotment",
            confirmed_without_identifier_reason: "Supplier will issue later"
          }
        },
        idempotency_key: key
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "response succeeds on predecessor requested revision after successor activation" do
    planned = create_reservation.record
    predecessor_version = @version
    predecessor_version.update!(status: "superseded", superseded_at: Time.current)
    successor = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 2,
      status: "activated",
      activated_at: Time.current,
      copied_from: predecessor_version
    )
    @arrangement.update!(governing_version: successor)

    assert_equal "superseded", predecessor_version.reload.status
    assert_equal successor.id, @arrangement.reload.governing_version_id

    result = respond_reservation(@reservation)
    assert_equal :created, result.status
    assert_equal "response", result.record.event_kind

    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierReservationRequest.new(
        agency: @agency, actor: @actor, reservation: planned,
        attributes: { channel: "email", reference_note: "Should fail" },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "partial response replay succeeds while other scopes remain pending" do
    revision = @reservation.revisions.where(status: "requested").sole
    first_scope, = revision.scopes.order(:position, :id).to_a
    key = SecureRandom.uuid
    attrs = {
      scope_ids: [ first_scope.id ],
      channel: "portal",
      reference_note: "Partial confirm",
      outcomes: { first_scope.id => { outcome_kind: "confirmed" } },
      evidence: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Partial confirm",
        confirmed_without_identifier_reason: "Supplier will issue later"
      }
    }

    result = RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: @reservation,
      attributes: attrs, idempotency_key: key
    ).call
    assert_equal :created, result.status
    assert_equal "partially_confirmed", @reservation.projection.reload.state

    assert_no_changes -> { SupplierReservationEvent.count } do
      replay = RecordSupplierReservationResponse.new(
        agency: @agency, actor: @actor, reservation: @reservation,
        attributes: attrs, idempotency_key: key
      ).call
      assert_equal :replayed, replay.status
      assert_equal result.record.id, replay.record.id
    end
  end

  test "blank scope_ids response replay recovers only the originally pending scopes" do
    revision = @reservation.revisions.where(status: "requested").sole
    first_scope, second_scope = revision.scopes.order(:position, :id).to_a
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: @reservation,
      attributes: {
        scope_ids: [ first_scope.id ],
        channel: "portal",
        reference_note: "First scope",
        outcomes: { first_scope.id => { outcome_kind: "confirmed" } },
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "First scope",
          confirmed_without_identifier_reason: "Later"
        }
      },
      idempotency_key: SecureRandom.uuid
    ).call

    key = SecureRandom.uuid
    attrs = {
      channel: "portal",
      reference_note: "Remaining scopes",
      outcomes: { second_scope.id => { outcome_kind: "confirmed" } },
      evidence: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Remaining scopes",
        confirmed_without_identifier_reason: "Later"
      }
    }

    result = RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: @reservation,
      attributes: attrs, idempotency_key: key
    ).call
    assert_equal :created, result.status
    assert_equal [ second_scope.id ], result.record.scope_outcomes.map(&:supplier_reservation_scope_id)

    assert_no_changes -> { SupplierReservationEvent.count } do
      replay = RecordSupplierReservationResponse.new(
        agency: @agency, actor: @actor, reservation: @reservation,
        attributes: attrs, idempotency_key: key
      ).call
      assert_equal :replayed, replay.status
      assert_equal result.record.id, replay.record.id
    end
  end

  test "mutation graph locks version before reservation and revision" do
    source = File.read(Rails.root.join("app/services/reservation_command_support.rb"))
    version_idx = source.index("arrangement.versions.lock.find")
    reservation_idx = source.index("@agency.supplier_reservations.lock.find(unlocked.id)")
    revision_idx = source.index("reservation.revisions.lock.find_by")
    assert version_idx < reservation_idx
    assert reservation_idx < revision_idx
  end

  private

  def activate_version_directly
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  def create_reservation(idempotency_key: SecureRandom.uuid)
    CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [
          { target_kind: "arrangement", label: "Whole" },
          {
            target_kind: "occurrence",
            service_occurrence_id: @graph[:occurrence].id,
            requested_quantity: 12,
            quantity_basis: "traveler_positions",
            label: "Arrival service"
          }
        ]
      },
      idempotency_key: idempotency_key
    ).call
  end

  def request_reservation(reservation, idempotency_key: SecureRandom.uuid)
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: idempotency_key
    ).call
  end

  def respond_reservation(reservation, idempotency_key: SecureRandom.uuid, outcomes: nil)
    scopes = reservation.revisions.where(status: "requested").sole.scopes.order(:position)
    outcomes ||= scopes.map { |scope| [ scope.id, { outcome_kind: "confirmed" } ] }.to_h
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: {
        channel: "portal",
        reference_note: "Confirmed allotment",
        outcomes: outcomes,
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed allotment",
          confirmed_without_identifier_reason: "Supplier will issue later"
        }
      },
      idempotency_key: idempotency_key
    ).call
  end
end
