require "test_helper"

class M3d5ReservationResponseRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "HTTP Response Supplier")
    @departure = create_capacity_departure(@agency, name: "HTTP Response")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "HTTP Response", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
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
    @trigger = SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      trigger_kind: "reservation_confirmation",
      authority_shape: "confirmed_amount",
      committed_supplier: @supplier,
      description: "Deposit",
      currency: @departure.operating_currency,
      position: 1
    )
  end

  test "show renders keyed commitment inputs and response posts keyed amounts" do
    sign_in_as @staff
    get departure_arrangement_reservation_path(@departure, @arrangement, @reservation)
    assert_response :success
    assert_select "input[name='confirmed_amounts_minor_units[#{@trigger.id}]']"
    assert_select "input[name='response_event[identifier][display_value]']"
    scope = @reservation.revisions.where(status: "requested").sole.scopes.sole
    assert_select "input[name='outcomes[#{scope.id}][quantity]']"
    assert_select "input[name='outcomes[#{scope.id}][supplier_note]']"

    post respond_departure_arrangement_reservation_path(@departure, @arrangement, @reservation), params: {
      idempotency_key: SecureRandom.uuid,
      scope_ids: [ scope.id ],
      outcomes: {
        scope.id => { outcome_kind: "confirmed", quantity: 4, quantity_basis: "traveler_positions", supplier_note: "OK" }
      },
      response_event: {
        channel: "portal",
        reference_note: "Confirmed",
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current.iso8601,
          reference_note: "Evidence note",
          confirmed_without_identifier_reason: "Later"
        }
      },
      confirmed_amounts_minor_units: { @trigger.id => "25000" }
    }
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, @reservation)
    commitment = SupplierCommitment.find_by!(supplier_commitment_trigger_definition_id: @trigger.id)
    assert_equal 25_000, commitment.amount_minor_units
  end

  test "activation show renders keyed amount fields per trigger" do
    sign_in_as @staff
    activation_trigger = SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "confirmed_amount",
      committed_supplier: @supplier,
      description: "Activation deposit",
      currency: @departure.operating_currency,
      position: 2
    )
    # Reset to draft for activation UI
    @arrangement.update!(status: "draft", governing_version: nil)
    @version.update!(status: "draft", activated_at: nil)
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item], charging_supplier: @supplier,
      label: "Lodging", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source, stage: "contracted",
      status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @staff, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:http",
      readiness_provenance: "Signed"
    )

    get departure_arrangement_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "input[name='confirmed_amounts_minor_units[#{activation_trigger.id}]']"
    assert_select "input[name='confirmed_amount_minor_units']", count: 0
  end
end
