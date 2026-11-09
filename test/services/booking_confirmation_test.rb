require "test_helper"

# Slice 1 step 6c: BKG-25, BKG-28, BKG-39, BKG-41, BKG-45, BKG-46,
# CMN-01 to CMN-03, SMN-02, SMN-11, SMN-32, SUP-35, D-75, D-81, D-94;
# step 6 plan questions 2, 3, 9 to 11.
class BookingConfirmationTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @agency.update_columns(default_timezone: AlphaFixture::TIME_ZONE)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @booking = @alpha.bookings.fetch("BK-104")
  end

  test "acceptance locks the terms version and copies the agency tiers it followed (BKG-28, question 9)" do
    terms = @alpha.client_terms
    UpdateClientTerms.new(agency: @agency, actor: @admin, departure: @alpha.departure, terms_version: terms,
      attributes: { overrides_cancellation_tiers: "false" }, lock_version: terms.reload.lock_version).call
    agency_days = @agency.agency_cancellation_tiers.ordered.map(&:min_days_before_departure)

    accept!(@booking)
    terms.reload
    assert terms.locked?
    assert_equal agency_days, terms.cancellation_tiers.map(&:min_days_before_departure)
    assert terms.own_cancellation_tiers.all?(&:copied_from_agency_default?)

    SaveCancellationTier.new(agency: @agency, actor: @admin, attributes: { min_days_before_departure: "30", charge_kind: "percentage", percentage: "75" }).call
    assert_equal agency_days, terms.reload.cancellation_tiers.map(&:min_days_before_departure), "a later agency change touches nothing accepted"
    refused = assert_raises(AgencyCommand::Error) { UpdateClientTerms.new(agency: @agency, actor: @admin, departure: @alpha.departure, terms_version: terms, attributes: { departure_wording: "Changed" }, lock_version: terms.lock_version).call }
    assert_match(/locked/, refused.message)

    second = StartNextClientTermsVersion.new(agency: @agency, actor: @admin, departure: @alpha.departure).call.record
    assert_equal [ 2, false, false ], [ second.version_number, second.locked?, second.overrides_cancellation_tiers? ]
    assert_empty second.own_cancellation_tiers, "a version that followed the agency follows it again"
  end

  test "a change to the price or terms makes an acceptance stale (BKG-39)" do
    accept!(@booking)
    assert @booking.reload.current_acceptance
    milo = @booking.booking_travelers.find { |row| row.traveler.given_names == "Milo" }
    SaveBookingTraveler.new(agency: @agency, actor: @staff, booking: @booking, booking_traveler: milo,
      attributes: { traveler_type_id: @agency.traveler_types.find_by!(name: "Child").id }, lock_version: milo.lock_version).call
    assert_nil @booking.reload.current_acceptance
    assert_includes BookingConfirmationCheck.new(@booking).blockers.map(&:message),
      "The recorded acceptance no longer covers the current price and terms; record the client's acceptance again."
  end

  test "a payment counts as acceptance only when the terms say so, and names the recorded payment (BKG-41, D5, D-94 (3))" do
    trip = @booking.client_trip
    wire = RecordClientPayment.new(agency: @agency, actor: @admin, trip:, attributes: {
      payer_client_id: trip.client_id, paid_on: "2027-01-12", amount: "500", route: "agency", payment_method: "bank_transfer", reference: "Wire 4471"
    }).call.record
    payment = { accepted_by: "Sofia Bennett", acceptance_method: "designated_payment", client_payment_id: wire.id }
    refused = assert_raises(AgencyCommand::Error) { RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: payment).call }
    assert_match(/counts only when the client terms say so/, refused.message)

    deposit = @alpha.client_terms.schedule_lines.find_by!(description: "Deposit")
    SaveClientScheduleLine.new(agency: @agency, actor: @admin, departure: @alpha.departure, terms_version: @alpha.client_terms, line: deposit,
      attributes: deposit.attributes.slice("description", "basis", "service_category", "due_rule").merge("amount" => "500", "counts_as_acceptance" => "1"),
      lock_version: deposit.lock_version).call
    missing = assert_raises(AgencyCommand::Error) do
      RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: payment.merge(client_payment_id: nil)).call
    end
    assert_match(/record the client's payment on the trip first/, missing.message)
    acceptance = RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: payment).call.record
    assert_equal wire, acceptance.client_payment
    assert_raises(ActiveRecord::StatementInvalid) { BookingAcceptance.transaction(requires_new: true) { BookingAcceptance.where(id: acceptance.id).update_all(client_payment_id: nil) } }

    ReverseClientPayment.new(agency: @agency, actor: @admin, payment: wire, reason: "Recalled by the bank").call
    reversed = assert_raises(AgencyCommand::Error) { RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: payment).call }
    assert_match(/reversed/, reversed.message)
  end

  test "email acceptance needs evidence; phone needs a note" do
    missing = assert_raises(AgencyCommand::Error) { RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: { accepted_by: "Sofia", acceptance_method: "email" }).call }
    assert_match(/Evidence is required/, missing.message)
    note = assert_raises(AgencyCommand::Error) { RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: { accepted_by: "Sofia", acceptance_method: "phone" }).call }
    assert_match(/Note is required/, note.message)

    file = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n".b), "application/pdf", original_filename: "acceptance.pdf")
    acceptance = RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: { accepted_by: "Sofia Bennett", acceptance_method: "email" }, evidence: file).call.record
    assert acceptance.evidence.attached?
    assert_match(/\A[0-9a-f]{64}\z/, acceptance.evidence_sha256)
  end

  test "confirmation reserves the space, snapshots the charge and names, and is refused without acceptance (BKG-25, BKG-45, D5)" do
    refused = assert_raises(ConfirmClientBooking::Blocked) { ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call }
    assert_equal [ "Record the client's acceptance of the current price and terms." ], refused.blockers.map(&:message)

    accept!(@booking)
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call
    @booking.reload
    assert @booking.status_confirmed?
    assert @booking.inventory_allocations.all?(&:state_reserved?)
    assert_equal [ "Sofia Bennett", "Marcus Bennett", "Ava Bennett", "Milo Bennett" ], @booking.booking_travelers.map(&:name_as_booked)
    charge = @booking.client_charge
    assert_equal [ 1_257_000, 24, @alpha.client_terms ], [ charge.total_minor_units, charge.lines.size, charge.client_terms_version ]
    assert_equal 1_124_000, charge.lines.select { |line| line.line_type == "traveler_price" && line.description == "Cabin 1: S01" }.sum(&:amount_minor_units)
    assert_raises(ActiveRecord::StatementInvalid) { ChargeLine.transaction(requires_new: true) { ChargeLine.where(client_charge_id: charge.id).update_all(amount_minor_units: 1) } }
    assert_raises(ActiveRecord::StatementInvalid) { BookingPriceLine.transaction(requires_new: true) { BookingPriceLine.where(client_booking_id: @booking.id).delete_all } }
    assert_raises(AgencyCommand::Error) { ReleaseBookingHold.new(agency: @agency, actor: @staff, booking: @booking).call }
  end

  test "confirmation proposes cost and commission from the rate table, and posts $450 for its cabin only (SUP-35, SMN-32, D-81, question 11)" do
    accept!(@booking)
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call
    s01 = @alpha.arrangements.fetch(:cruise).inventory_groups.find_by!(label: "S01")
    proposal = ProposeBookingSupplierCost.new(group: s01, guests: @booking.booking_travelers.map(&:traveler_type)).call
    line = @booking.cost_lines.sole
    assert_equal [ "client_booking", "committed", proposal.gross ], line.values_at(:scope, :stage, :amount_minor_units)
    commission = @booking.expected_commissions.sole
    assert_equal [ proposal.commission, "expected" ], commission.values_at(:amount_minor_units, :status)

    cruise = @alpha.arrangements.fetch(:cruise)
    full = AmountDue.where(supplier_arrangement: cruise).where.not(unit_shell_id: nil)
    assert_equal [ [ "S01-01", 45_000, Date.new(2027, 1, 12) ] ], full.map { |amount| [ amount.unit_shell.label, amount.amount_minor_units, amount.due_on ] }
    event = TriggerEvent.find_by!(client_booking: @booking, supplier_arrangement: cruise)
    assert_equal [ "S01-01" ], event.event_shells.map { |row| row.unit_shell.label }
  end

  test "a cabin already committed as unsold space gets no further cost, but still its commission (D-75)" do
    cruise = @alpha.arrangements.fetch(:cruise)
    shell = @booking.inventory_allocations.find { |allocation| allocation.inventory_group.label == "S01" }.unit_shell
    SaveCostLine.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: cruise,
      attributes: { scope: "unit_shells", unit_shell_ids: [ shell.id ], description: "Unsold S01 commitment", basis: "fixed", rate: "5000", stage: "committed" }).call
    accept!(@booking)
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call
    assert_empty @booking.reload.cost_lines
    assert_equal 1, @booking.expected_commissions.size
  end

  test "overrides need Supplier arrangements or Financial records, and keep the proposal (SUP-35)" do
    accept!(@booking)
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call
    commission = @booking.reload.expected_commissions.sole
    refused = assert_raises(AgencyCommand::Error) { OverrideBookingSupplierCost.new(agency: @agency, actor: @staff, booking: @booking, commission:, amount: "1000").call }
    assert_equal :unauthorized, refused.code
    OverrideBookingSupplierCost.new(agency: @agency, actor: @admin, booking: @booking, commission:, amount: "1000").call
    assert_equal [ 100_000, 182_000, @admin ], commission.reload.values_at(:amount_minor_units, :proposed_amount_minor_units, :overridden_by)
    refused = assert_raises(AgencyCommand::Error) do
      SaveCostLine.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @alpha.arrangements.fetch(:cruise), cost_line: @booking.cost_lines.sole,
        attributes: { description: "Edited" }, lock_version: @booking.cost_lines.sole.lock_version).call
    end
    assert_match(/change it from the booking/, refused.message)
  end

  private

  def accept!(booking)
    RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking:, attributes: { accepted_by: "Sofia Bennett", acceptance_method: "phone", note: "Accepted by phone." }).call.record
  end
end
