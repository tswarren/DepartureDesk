require "test_helper"

class SearchSupplierArrangementsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Search Supplier")
    @departure = create_capacity_departure(@agency, name: "Search Departure")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Searchable Arrangement",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
  end

  test "blank query browses arrangements and name query ranks exact matches" do
    blank = SearchSupplierArrangements.call(agency: @agency, actor: @actor, departure_id: @departure.id)
    assert_includes blank.records.map(&:id), @arrangement.id

    result = SearchSupplierArrangements.call(
      agency: @agency, actor: @actor, query: @arrangement.name, departure_id: @departure.id
    )
    assert_equal @arrangement.id, result.records.first.id
  end
end

class RecordExistingConfirmedSupplierReservationTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Existing Booking Supplier")
    @departure = create_capacity_departure(@agency, name: "Existing Booking Departure")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Existing",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  test "records planned request response and confirmation atomically" do
    result = RecordExistingConfirmedSupplierReservation.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        booking_supplier_id: @supplier.id,
        scopes: { "0" => { target_kind: "arrangement", label: "Whole" } },
        channel: "portal",
        reference_note: "Already confirmed",
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Already confirmed",
          confirmed_without_identifier_reason: "External booking reference retained"
        }
      }
    ).call

    reservation = result.record
    assert_equal :created, result.status
    assert_equal "confirmed", reservation.projection.reload.state
    assert SupplierConfirmationReservationResponseLink.exists?(supplier_reservation_id: reservation.id)
  end
end
