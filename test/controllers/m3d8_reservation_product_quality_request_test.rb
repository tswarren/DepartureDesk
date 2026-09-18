require "test_helper"

class M3d8ReservationProductQualityRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "M3D8 Quality Supplier")
    @departure = create_capacity_departure(@agency, name: "M3D8 Quality")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "M3D8", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  test "new reservation form uses canonical field classes and one default scope" do
    sign_in_as @staff
    get new_departure_arrangement_reservation_path(@departure, @arrangement)
    assert_response :success
    assert_select "select.dd-field#supplier_reservation_booking_supplier_id"
    assert_select "[data-reservation-scope-fields-target=list] select.dd-field#supplier_reservation_scopes_0_target_kind"
    assert_select "[data-reservation-scope-fields-target=list] select[id$='_target_kind']", count: 1
    assert_select ".dd-input", count: 0
    assert_select ".dd-select", count: 0
    assert_select ".dd-textarea", count: 0
    assert_select ".dd-error-summary", count: 0
  end

  test "reservation list is truncated at fifty with query bound proof" do
    51.times do |index|
      CreateSupplierReservation.new(
        agency: @agency, actor: @staff, arrangement: @arrangement,
        attributes: {
          booking_supplier_id: @supplier.id,
          supplier_arrangement_version_id: @version.id,
          scopes: [ { target_kind: "arrangement", label: "Row #{index}" } ]
        },
        idempotency_key: SecureRandom.uuid
      ).call
    end

    sign_in_as @staff
    query_count = request_query_count do
      get departure_arrangement_reservations_path(@departure, @arrangement)
    end
    assert_response :success
    assert_select "table.dd-table--reservations tbody tr", count: 50
    assert_match(/Showing the first 50/, response.body)
    assert_operator query_count, :<=, 25

    explain = ActiveRecord::Base.connection.select_value(
      "EXPLAIN #{ListSupplierReservations.new(agency: @agency, arrangement: @arrangement).relation_for_explain.to_sql}"
    )
    assert_match(/Index|Seq Scan|Limit/i, explain.to_s)
  end

  test "failed create uses linked form error summary" do
    sign_in_as @staff
    post departure_arrangement_reservations_path(@departure, @arrangement), params: {
      idempotency_key: SecureRandom.uuid,
      supplier_reservation: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: { "0" => { target_kind: "not_a_real_kind", label: "Broken" } }
      }
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary.dd-alert.dd-alert--danger[role=alert][tabindex='-1']"
    assert_select "#form-error-summary p.dd-alert-title", text: "Please fix the following:"
    assert_select ".dd-error-summary", count: 0
  end

  test "show opens at most one composer and preserves withdrawal reason" do
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @staff, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_as @staff
    get departure_arrangement_reservation_path(@departure, @arrangement, reservation)
    assert_response :success
    assert_select "form[action*='withdraw']", count: 0
    assert_select "form[action*='respond']", count: 0

    get departure_arrangement_reservation_path(@departure, @arrangement, reservation, composer: "withdraw")
    assert_response :success
    assert_select "form[action*='withdraw']", count: 1
    assert_select "form[action*='respond']", count: 0

    post withdraw_departure_arrangement_reservation_path(@departure, @arrangement, reservation), params: {
      idempotency_key: SecureRandom.uuid,
      scope_ids: [ reservation.revisions.where(status: "requested").sole.scopes.sole.id ],
      reason: ""
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "textarea#withdraw_reason"
  end

  private

  def request_query_count
    queries = []
    callback = ->(*, payload) do
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].to_s.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end
end
