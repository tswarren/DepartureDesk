require "test_helper"

# BKG-28, BKG-31, BKG-41, CMN-09, D-76, D-77.
class ClientTermsCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Terms", operating_currency: "USD", starts_on: "2027-11-06", ends_on: "2027-11-13" }).call.record
    UpdateClientTermsDefaults.new(agency: @agency, actor: @admin, wording: "Agency terms.", lock_version: @agency.reload.lock_version).call
    agency_tier!(min_days_before_departure: "120", charge_kind: "percentage", percentage: "10")
    agency_tier!(min_days_before_departure: "0", charge_kind: "percentage", percentage: "100")
  end

  test "a Departure's version 1 copies the agency wording and follows the agency tiers until it overrides them (BKG-28, BKG-31)" do
    version = start!.record
    assert_equal [ 1, "Agency terms." ], [ version.version_number, version.agency_wording ]
    assert_equal [ 120, 0 ], version.cancellation_tiers.map(&:min_days_before_departure)
    assert_equal :noop, start!.status

    UpdateClientTerms.new(agency: @agency, actor: @admin, departure: @departure, terms_version: version, attributes: { overrides_cancellation_tiers: "1", departure_wording: "Alpha extras." },
      lock_version: version.lock_version).call
    version.reload
    assert_equal [ 120, 0 ], version.cancellation_tiers.map(&:min_days_before_departure), "the override starts from the agency's tiers"
    tier!(version, min_days_before_departure: "61", charge_kind: "percentage", percentage: "50")
    agency_tier!(min_days_before_departure: "30", charge_kind: "percentage", percentage: "75")
    assert_equal [ 120, 61, 0 ], version.reload.cancellation_tiers.map(&:min_days_before_departure), "an override replaces the default whole"

    UpdateClientTerms.new(agency: @agency, actor: @admin, departure: @departure, terms_version: version, attributes: { overrides_cancellation_tiers: "0" },
      lock_version: version.lock_version).call
    assert_equal [ 120, 30, 0 ], version.reload.cancellation_tiers.map(&:min_days_before_departure)
    assert_empty version.own_cancellation_tiers
  end

  test "tiers charge a percentage or a fixed amount per traveler or per unit of a category, one per day count" do
    version = start!.record
    assert_match(/already a tier/, assert_raises(AgencyCommand::Error) { agency_tier!(min_days_before_departure: "120", charge_kind: "percentage", percentage: "5") }.message)
    per_unit = agency_tier!(min_days_before_departure: "90", charge_kind: "fixed_per_unit", amount: "500", service_category: "cruise")
    assert_equal [ 50_000, "USD", "cruise" ], per_unit.values_at(:amount_minor_units, :currency, :service_category)
    assert_raises(ActiveRecord::StatementInvalid) do
      AgencyCancellationTier.transaction(requires_new: true) { AgencyCancellationTier.where(id: per_unit.id).update_all(service_category: nil) }
    end
    refused = assert_raises(AgencyCommand::Error) { tier!(version, min_days_before_departure: "10", charge_kind: "percentage", percentage: "5") }
    assert_match(/Override the agency tiers/, refused.message)
  end

  test "the payment schedule: a per-cabin deposit, one balance, at most one acceptance payment (CMN-09, D-77, BKG-41)" do
    version = start!.record
    assert_equal [ "Add a balance line to the payment schedule." ], version.booking_blockers
    deposit = line!(version, description: "Deposit", basis: "per_unit", service_category: "cruise", amount: "500", due_rule: "at_confirmation").record
    assert_equal [ 50_000, "cruise", false ], deposit.values_at(:amount_minor_units, :service_category, :counts_as_acceptance)
    line!(version, description: "Balance", basis: "balance", due_rule: "days_before_departure", days_before_departure: "120")
    assert_empty version.reload.booking_blockers

    assert_match(/already has a balance/, assert_raises(AgencyCommand::Error) { line!(version, description: "Again", basis: "balance", due_rule: "at_confirmation") }.message)
    line!(version, description: "Deposit", basis: "per_unit", service_category: "cruise", amount: "500", due_rule: "at_confirmation", counts_as_acceptance: "1", line: deposit)
    assert deposit.reload.counts_as_acceptance
    assert_raises(AgencyCommand::Error) { line!(version, description: "Fee", basis: "per_booking", amount: "25", due_rule: "at_confirmation", counts_as_acceptance: "1") }
    assert_match(/service category/, assert_raises(AgencyCommand::Error) { line!(version, description: "X", basis: "per_unit", amount: "1", due_rule: "at_confirmation") }.message)
  end

  test "copying another Departure's terms gives an independent copy (D-76)" do
    source = start!.record
    UpdateClientTerms.new(agency: @agency, actor: @admin, departure: @departure, terms_version: source, attributes: { overrides_cancellation_tiers: "1", departure_wording: "Source wording." },
      lock_version: source.lock_version).call
    line!(source.reload, description: "Balance", basis: "balance", due_rule: "days_before_departure", days_before_departure: "90")

    target = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Copy", operating_currency: "USD" }).call.record
    copy = StartClientTerms.new(agency: @agency, actor: @admin, departure: target, source_departure_id: @departure.id).call.record
    assert_equal [ "Source wording.", true, @departure ], [ copy.departure_wording, copy.overrides_cancellation_tiers, copy.copied_from_departure ]
    assert_equal [ 120, 0 ], copy.own_cancellation_tiers.map(&:min_days_before_departure)
    assert_equal [ "Balance" ], copy.schedule_lines.map(&:description)

    line!(source.reload, description: "Deposit", basis: "per_booking", amount: "100", due_rule: "at_confirmation")
    assert_equal 1, copy.schedule_lines.reload.size, "the copy doesn't follow its source"
    assert AuditEvent.exists?(subject_id: target.id, action: "departure.client_terms_copied")
  end

  test "a locked version and its rows never change, in the commands and the database (BKG-28)" do
    version = start!.record
    line = line!(version, description: "Balance", basis: "balance", due_rule: "at_confirmation").record
    version.update_columns(locked_at: Time.current)
    assert_match(/locked/, assert_raises(AgencyCommand::Error) { line!(version, description: "X", basis: "per_booking", amount: "1", due_rule: "at_confirmation") }.message)
    assert_raises(ActiveRecord::StatementInvalid) { ClientPaymentScheduleLine.transaction(requires_new: true) { ClientPaymentScheduleLine.where(id: line.id).delete_all } }
    assert_raises(ActiveRecord::StatementInvalid) { ClientTermsVersion.transaction(requires_new: true) { ClientTermsVersion.where(id: version.id).update_all(departure_wording: "X") } }
  end

  test "agency defaults need an Agency Admin; Departure terms need Departure management" do
    staff = agency_users(:harbor_staff)
    assert_equal :unauthorized, assert_raises(AgencyCommand::Error) {
      UpdateClientTermsDefaults.new(agency: @agency, actor: staff, wording: "X", lock_version: @agency.reload.lock_version).call
    }.code
    assert StartClientTerms.new(agency: @agency, actor: staff, departure: @departure).call.record.persisted?
    assert_equal :unauthorized, assert_raises(AgencyCommand::Error) {
      StartClientTerms.new(agency: @agency, actor: agency_users(:harbor_baseline_staff), departure: @departure).call
    }.code
  end

  private

  def start! = StartClientTerms.new(agency: @agency, actor: @admin, departure: @departure).call

  def agency_tier!(**attributes)
    SaveCancellationTier.new(agency: @agency, actor: @admin, attributes:).call.record
  end

  def tier!(version, **attributes)
    SaveCancellationTier.new(agency: @agency, actor: @admin, departure: @departure, terms_version: version, attributes:).call.record
  end

  def line!(version, line: nil, **attributes)
    SaveClientScheduleLine.new(agency: @agency, actor: @admin, departure: @departure, terms_version: version, line:,
      attributes:, lock_version: line&.reload&.lock_version).call
  end
end
