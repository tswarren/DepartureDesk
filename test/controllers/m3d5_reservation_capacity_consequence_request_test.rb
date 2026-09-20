require "test_helper"

class M3d5ReservationCapacityConsequenceRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper
  include CapacityActivatedGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Capacity Consequence Supplier")
    @departure = create_capacity_departure(@agency, name: "Capacity Consequence")
    @graph = build_activated_established_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      actor: @staff,
      prefix: "Response Cap"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @pool = @graph[:pool]
    @reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @staff, reservation: @reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
    @scope = @reservation.revisions.where(status: "requested").sole.scopes.sole
  end

  test "show offers closed capacity event types and blank rows do not block response" do
    sign_in_as @staff
    get departure_arrangement_reservation_path(@departure, @arrangement, @reservation, composer: "respond")
    assert_response :success
    assert_select "select[name='capacity_consequences[0][capacity_pool_id]'] option[value='#{@pool.id}']"
    assert_select "select[name='capacity_consequences[0][event_type]'] option[value='increased']"
    assert_select "select[name='capacity_consequences[0][event_type]'] option[value='released']"
    assert_select "select[name='capacity_consequences[0][event_type]'] option[value='withdrawn']"
    assert_select "select[name='capacity_consequences[0][event_type]'] option[value='hold']", count: 0
    assert_select "select[name='capacity_consequences[0][event_type]'] option[value='reinstated']", count: 0
    assert_select "button[data-action='reservation-response-fields#removeCapacity']", minimum: 1
    assert_select "button[data-action='reservation-response-fields#addCapacity']", text: "Add capacity consequence"

    assert_difference -> { SupplierReservationEvent.where(event_kind: "response").count }, 1 do
      post respond_departure_arrangement_reservation_path(@departure, @arrangement, @reservation), params: {
        idempotency_key: SecureRandom.uuid,
        scope_ids: [ @scope.id ],
        outcomes: { @scope.id => { outcome_kind: "confirmed" } },
        response_event: {
          channel: "portal",
          reference_note: "Confirmed without capacity",
          evidence: {
            evidence_kind: "supplier_confirmation",
            evidence_on: Date.current.iso8601,
            reference_note: "Confirmed",
            confirmed_without_identifier_reason: "Later"
          }
        },
        capacity_consequences: {
          "0" => { capacity_pool_id: "", event_type: "", quantity: "", effective_on: "" },
          "1" => { capacity_pool_id: "", event_type: "", quantity: "", effective_on: "" }
        }
      }
    end
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, @reservation)
  end

  test "partial capacity row without pool is invalid and valid increased appends" do
    sign_in_as @staff
    post respond_departure_arrangement_reservation_path(@departure, @arrangement, @reservation), params: {
      idempotency_key: SecureRandom.uuid,
      scope_ids: [ @scope.id ],
      outcomes: { @scope.id => { outcome_kind: "confirmed" } },
      response_event: {
        channel: "portal",
        reference_note: "Partial capacity",
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current.iso8601,
          reference_note: "Partial",
          confirmed_without_identifier_reason: "Later"
        }
      },
      capacity_consequences: {
        "0" => {
          capacity_pool_id: "",
          event_type: "increased",
          quantity: "1",
          effective_on: Date.current.iso8601
        }
      }
    }
    assert_response :unprocessable_entity
    assert_match(/Capacity Pool|clear the other fields/i, flash.now[:alert].to_s + response.body)

    assert_difference -> { @pool.capacity_events.where(event_type: "increased").count }, 1 do
      post respond_departure_arrangement_reservation_path(@departure, @arrangement, @reservation), params: {
        idempotency_key: SecureRandom.uuid,
        scope_ids: [ @scope.id ],
        outcomes: { @scope.id => { outcome_kind: "confirmed" } },
        response_event: {
          channel: "portal",
          reference_note: "With capacity",
          evidence: {
            evidence_kind: "supplier_confirmation",
            evidence_on: Date.current.iso8601,
            reference_note: "With capacity",
            confirmed_without_identifier_reason: "Later"
          }
        },
        capacity_consequences: {
          "0" => {
            capacity_pool_id: @pool.id,
            event_type: "increased",
            quantity: "2",
            effective_on: @graph[:occurrence_definition].starts_on.iso8601
          }
        }
      }
    end
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, @reservation)
  end
end
