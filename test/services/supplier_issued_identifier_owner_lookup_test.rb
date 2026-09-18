require "test_helper"

class SupplierIssuedIdentifierOwnerLookupTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Owner Lookup Supplier")
    @departure = create_capacity_departure(@agency, name: "Owner Lookup")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "OwnerLookup", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
    @confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      confirming_supplier: @supplier,
      actor: @actor,
      recorded_at: Time.current,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current,
      channel: "portal",
      reference_note: "Evidence",
      confirmed_without_identifier_reason: "n/a"
    )
    @reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  test "arrangement owner treats reservation-owned match as foreign" do
    reservation_owned = create_identifier(reservation: @reservation, value: "GRP-1")
    arrangement_owned = create_identifier(reservation: nil, value: "GRP-2")

    lookup = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: @supplier.id,
      identifier_type: "group_number",
      issuer_context: "cruise",
      normalized_value: "grp-1",
      arrangement: @arrangement,
      reservation: nil
    )
    assert_empty lookup.same_owner
    assert_includes lookup.foreign.map(&:id), reservation_owned.id

    same = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: @supplier.id,
      identifier_type: "group_number",
      issuer_context: "cruise",
      normalized_value: "grp-2",
      arrangement: @arrangement,
      reservation: nil
    )
    assert_equal [ arrangement_owned.id ], same.same_owner.map(&:id)
  end

  test "reservation owner treats arrangement-owned match as foreign" do
    arrangement_owned = create_identifier(reservation: nil, value: "GRP-9")
    lookup = SupplierIssuedIdentifierOwnerLookup.call(
      agency: @agency,
      supplier_id: @supplier.id,
      identifier_type: "group_number",
      issuer_context: "cruise",
      normalized_value: "grp-9",
      arrangement: @arrangement,
      reservation: @reservation
    )
    assert_empty lookup.same_owner
    assert_includes lookup.foreign.map(&:id), arrangement_owned.id
  end

  private

  def create_identifier(reservation:, value:)
    SupplierIssuedIdentifier.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_reservation: reservation,
      supplier: @supplier,
      issuer_context: "cruise",
      identifier_type: "group_number",
      display_value: value,
      normalized_value: value.downcase,
      first_supplier_confirmation: @confirmation
    )
  end
end
