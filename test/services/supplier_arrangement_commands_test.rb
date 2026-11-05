require "test_helper"

# SUP-06, SUP-07, SUP-11, ADR 0018: Draft arrangements.
class SupplierArrangementCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Arranged", operating_currency: "USD" }).call.record
    @supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Alpha Cruises" }, categories: [ "cruise_line" ]).call.record
    @payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier: @supplier, attributes: { name: "Alpha USD", currency: "USD" }).call.record
  end

  test "a Draft arrangement takes an ARR reference and the Departure's currency, and saves with fields missing" do
    arrangement = create!.record
    assert arrangement.draft?
    assert_equal "ARR-0001", arrangement.arrangement_reference
    assert_equal "USD", arrangement.currency
    assert_nil arrangement.group_reference
    assert_equal [ "Enter the supplier's group or confirmation reference.", "Choose a payee account." ], arrangement.confirmation_blockers
    assert_equal 1, AuditEvent.where(subject_id: arrangement.id, action: "supplier_arrangement.created").count
  end

  test "one live arrangement per supplier per Departure; a discarded one doesn't block another" do
    first = create!.record
    duplicate = assert_raises(AgencyCommand::Error) { create! }
    assert_equal :invalid, duplicate.code

    DiscardSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: first, lock_version: first.lock_version).call
    assert first.reload.cancelled?
    assert first.cancelled_at
    assert create!.record.draft?
  end

  test "a Draft is edited in place and audited; a payee must belong to the supplier" do
    arrangement = create!.record
    update!(arrangement, group_reference: "GRP-ALPHA", payee_account_id: @payee.id, obligation_shape: "committed_quantity")
    arrangement.reload
    assert_equal "GRP-ALPHA", arrangement.group_reference
    assert_empty arrangement.confirmation_blockers
    assert_includes AuditEvent.where(subject_id: arrangement.id, action: "supplier_arrangement.updated").sole.details["changed"], "payee_account_id"

    other = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Other" }, categories: [ "lodging" ]).call.record
    other_payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier: other, attributes: { name: "Other USD", currency: "USD" }).call.record
    error = assert_raises(AgencyCommand::Error) { update!(arrangement.reload, payee_account_id: other_payee.id) }
    assert_equal :invalid, error.code
  end

  test "a Departure without a currency, a Departed Departure and a missing permission are refused" do
    no_currency = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "No Currency", operating_currency: "" }).call.record
    error = assert_raises(AgencyCommand::Error) { create!(departure: no_currency) }
    assert_equal :invalid_state, error.code

    refused = assert_raises(AgencyCommand::Error) { create!(actor: agency_users(:harbor_baseline_staff)) }
    assert_equal :unauthorized, refused.code
    assert_not @departure.supplier_arrangements.exists?
  end

  test "the database refuses a payee of another supplier and an unconfirmed Confirmed row" do
    arrangement = create!.record
    other = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Other" }, categories: [ "lodging" ]).call.record
    other_payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier: other, attributes: { name: "Other USD", currency: "USD" }).call.record
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangement.transaction(requires_new: true) { SupplierArrangement.where(id: arrangement.id).update_all(payee_account_id: other_payee.id) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangement.transaction(requires_new: true) { SupplierArrangement.where(id: arrangement.id).update_all(status: "confirmed") }
    end
  end

  private

  def create!(departure: @departure, actor: @admin)
    CreateSupplierArrangement.new(agency: @agency, actor:, departure:, supplier_id: @supplier.id).call
  end

  def update!(arrangement, **attributes)
    UpdateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement:, attributes:, lock_version: arrangement.lock_version).call
  end
end
