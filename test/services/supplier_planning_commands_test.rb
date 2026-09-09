require "test_helper"

class SupplierPlanningCommandsTest < ActiveSupport::TestCase
  setup do
    @departure = create_departure!(agencies(:one), actor: users(:one))
    @supplier = parties(:organization_one)
    assign_supplier_role!(@supplier, actor: users(:one)) unless @supplier.supplier_profile
  end

  test "staff with office access can create arrangement reservation resource and confirmation" do
    arrangement = create_arrangement!(actor: users(:staff_one))
    resource = CreateSupplierResource.new(
      agency: agencies(:one), actor: users(:staff_one), arrangement:, name: "Balcony", resource_kind: "cabin_category", capacity_unit: "cabin"
    ).call.supplier_resource
    reservation = CreateSupplierReservation.new(
      agency: agencies(:one), actor: users(:staff_one), arrangement:, name: "Cabin 101", resources: [ resource ]
    ).call.supplier_reservation
    confirmation = RecordSupplierConfirmation.new(
      agency: agencies(:one), actor: users(:staff_one), reservation:, issuer_party: @supplier, identifier_type: "supplier_confirmation", context: "portal", raw_value: "CONF-1"
    ).call.supplier_confirmation

    ConfirmSupplierReservation.new(agency: agencies(:one), actor: users(:staff_one), reservation:).call

    assert arrangement.draft?
    assert resource.active?
    assert reservation.reload.confirmed?
    assert confirmation.effective?
    assert_includes agencies(:one).audit_events.pluck(:action), "supplier_reservation.confirmed"
  end

  test "cross agency arrangement create is rejected" do
    error = assert_raises(MembershipCommand::Error) do
      CreateSupplierArrangement.new(
        agency: agencies(:one),
        actor: users(:one),
        departure: create_departure!(agencies(:two), actor: users(:two)),
        supplier_party: @supplier,
        name: "Forged"
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "reservation confirm requires identifier evidence or explicit reason" do
    arrangement = create_arrangement!
    reservation = CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement:, name: "Cabin 101").call.supplier_reservation

    error = assert_raises(MembershipCommand::Error) do
      ConfirmSupplierReservation.new(agency: agencies(:one), actor: users(:one), reservation:).call
    end
    assert_equal :confirmation_evidence_required, error.code

    ConfirmSupplierReservation.new(
      agency: agencies(:one), actor: users(:one), reservation:, without_identifier_reason: "Supplier confirmed by phone before issuing a reference"
    ).call
    assert reservation.reload.confirmed?
  end

  test "parent arrangement cancellation rejects nonterminal children and reservations" do
    parent = create_arrangement!(name: "Parent")
    create_arrangement!(name: "Child", parent_arrangement: parent)

    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:one), arrangement: parent, reason: "No longer needed").call
    end
    assert_equal :dependency, error.code

    leaf = create_arrangement!(name: "Reservation parent")
    CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement: leaf, name: "Cabin 101").call
    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:one), arrangement: leaf, reason: "No longer needed").call
    end
    assert_equal :dependency, error.code
  end

  test "staff cannot cancel an arrangement" do
    arrangement = create_arrangement!(actor: users(:staff_one))

    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:staff_one), arrangement:, reason: "No longer needed").call
    end
    assert_equal :unauthorized, error.code
  end

  test "resource deactivation rejects nonterminal reservation links" do
    arrangement = create_arrangement!
    resource = CreateSupplierResource.new(
      agency: agencies(:one), actor: users(:one), arrangement:, name: "Room", resource_kind: "room_type", capacity_unit: "room"
    ).call.supplier_resource
    CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement:, name: "Room request", resources: [ resource ]).call

    error = assert_raises(MembershipCommand::Error) do
      DeactivateSupplierResource.new(agency: agencies(:one), actor: users(:one), resource:, reason: "Closed").call
    end
    assert_equal :dependency, error.code
  end

  test "supplier planning blocks party deactivation with samples" do
    arrangement = create_arrangement!

    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(agency: agencies(:one), actor: users(:one), party: @supplier, reason: "Duplicate").call
    end
    assert_equal :party_dependency, error.code
    assert_match(/supplier arrangement/, error.message)
    assert_match(/#{arrangement.name}/, error.message)
  end

  test "transfer is frozen after first arrangement and rejected transfer writes no success audit" do
    target = CreateOffice.new(agency: agencies(:one), actor: users(:one), name: "Transfer Target", code: "T#{SecureRandom.hex(4).upcase[0, 8]}", default_timezone: agencies(:one).default_timezone).call.office
    GrantOfficeAccess.new(agency: agencies(:one), actor: users(:one), membership: agency_memberships(:one), office: target).call
    create_arrangement!
    before = agencies(:one).audit_events.where(action: "departure.office_transferred").count

    error = assert_raises(MembershipCommand::Error) do
      TransferDepartureOffice.new(agency: agencies(:one), actor: users(:one), departure: @departure, office: target).call
    end

    assert_equal :office_transfer_frozen, error.code
    assert_equal before, agencies(:one).audit_events.where(action: "departure.office_transferred").count
  end

  private

  def create_arrangement!(name: "Cruise Block", parent_arrangement: nil, actor: users(:one))
    CreateSupplierArrangement.new(
      agency: agencies(:one),
      actor:,
      departure: @departure,
      supplier_party: @supplier,
      parent_arrangement:,
      name:
    ).call.supplier_arrangement
  end
end
