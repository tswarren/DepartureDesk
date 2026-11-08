require "test_helper"

# Supplier reservations (INV-33 to INV-37, SUP-10; step 7 plan questions 1 to 7).
class SupplierReservationCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 1, 20, 15)
    @booking = @alpha.bookings.fetch("BK-104")
    @hotel = @alpha.arrangements.fetch(:hotel)
    @nights = @booking.choice_selections.select { |selection| selection.option.label.in?([ "Nov 2 Harbor Double", "Nov 3 Harbor Double" ]) }
  end

  def request!(selections = @nights, arrangement: @hotel, actor: @admin, booking: @booking)
    RequestSupplierReservation.new(agency: @agency, actor:, booking:, arrangement:, selection_ids: selections.map(&:id)).call
  end

  test "a request covers the booking's on-request nights and changes nothing else (INV-33, INV-37)" do
    before = [ @booking.price_lines.reload.map(&:amount_minor_units), @booking.inventory_allocations.reload.map(&:state), @booking.client_charge.lines.size ]
    reservation = request!.record
    assert_equal [ "requested", @booking, @hotel ], [ reservation.status, reservation.client_booking, reservation.supplier_arrangement ]
    assert_equal @nights.map(&:id).sort, reservation.units.map(&:choice_selection_id).sort
    assert_equal [ "requested" ], reservation.events.map(&:event_type)
    assert_equal before, [ @booking.price_lines.reload.map(&:amount_minor_units), @booking.inventory_allocations.reload.map(&:state), @booking.reload.client_charge.lines.size ]
    assert AuditEvent.exists?(action: "supplier_reservation.requested", subject_type: "SupplierReservation", subject_id: reservation.id)
  end

  test "accepting records the supplier's reference and date, and leaves prices and allocations alone (INV-35)" do
    reservation = request!.record
    lines = @booking.price_lines.reload.map(&:amount_minor_units)
    RecordSupplierReservationAcceptance.new(agency: @agency, actor: @admin, reservation:,
      attributes: { supplier_reference: "SHH-24117", responded_on: "2027-01-20", response_note: "Two Harbor Doubles held for the Bennetts." }).call
    reservation.reload
    assert_equal [ "confirmed", "SHH-24117", Date.new(2027, 1, 20) ], reservation.values_at(:status, :supplier_reference, :responded_on)
    assert_equal %w[requested confirmed], reservation.events.map(&:event_type)
    assert_equal lines, @booking.price_lines.reload.map(&:amount_minor_units)
    assert_equal "ALPHA-A", @alpha.arrangements.fetch(:cruise).reload.group_reference

    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierReservationAcceptance.new(agency: @agency, actor: @admin, reservation:, attributes: { supplier_reference: "X" }).call
    end
    assert_equal :invalid_state, error.code
  end

  test "acceptance needs a reference and a date not in the future" do
    reservation = request!.record
    assert_raises(AgencyCommand::Error) { RecordSupplierReservationAcceptance.new(agency: @agency, actor: @admin, reservation:, attributes: { supplier_reference: "" }).call }
    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierReservationAcceptance.new(agency: @agency, actor: @admin, reservation:, attributes: { supplier_reference: "SHH-1", responded_on: "2027-02-01" }).call
    end
    assert_match(/future/, error.message)
  end

  test "a unit has one open request, block space needs none, and a scope of none takes none (SUP-10)" do
    request!
    error = assert_raises(AgencyCommand::Error) { request!(@nights.first(1)) }
    assert_equal :conflict, error.code

    block = @booking.choice_selections.find { |selection| selection.inventory_group.label == "Nov 4 Harbor Double" }
    error = assert_raises(AgencyCommand::Error) { request!([ block ]) }
    assert_match(/group block/, error.message)

    @hotel.update_columns(reservation_scope: "none")
    other = @booking.choice_selections.find { |selection| selection.inventory_group.label == "Nov 5 Harbor Double" }
    error = assert_raises(AgencyCommand::Error) { request!([ other ]) }
    assert_match(/doesn't track supplier reservations/, error.message)
  end

  test "per-unit scope takes one unit per request and covers block space too" do
    @hotel.update_columns(reservation_scope: "per_unit")
    error = assert_raises(AgencyCommand::Error) { request! }
    assert_match(/one service at a time/, error.message)
    block = @booking.choice_selections.find { |selection| selection.inventory_group.label == "Nov 5 Harbor Double" }
    assert request!([ block ]).record.status_requested?
  end

  test "a service from another arrangement is refused, and baseline staff can't start a request" do
    cabin = @booking.choice_selections.find { |selection| selection.choice.name == "Cabin" }
    error = assert_raises(AgencyCommand::Error) { request!([ cabin ]) }
    assert_match(/isn't from/, error.message)

    error = assert_raises(AgencyCommand::Error) { request!(actor: agency_users(:harbor_baseline_staff)) }
    assert_equal :unauthorized, error.code
  end

  test "events are append-only in the application and in PostgreSQL" do
    event = request!.record.events.sole
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(occurred_on: Date.new(2027, 1, 1)) }
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservationEvent.transaction(requires_new: true) { SupplierReservationEvent.where(id: event.id).update_all(occurred_on: Date.new(2027, 1, 1)) }
    end
  end

  test "a confirmed reservation needs its reference and response, in the database" do
    reservation = request!.record
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservation.transaction(requires_new: true) { SupplierReservation.where(id: reservation.id).update_all(status: "confirmed") }
    end
  end
end
