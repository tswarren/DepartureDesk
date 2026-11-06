require "test_helper"

# SUP-02 payee accounts.
class SavePayeeAccountTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Alpha Cruises" }, categories: [ "cruise_line" ]).call.record
  end

  test "staff add and edit a payee account, audited against the supplier" do
    account = save!(name: "Alpha Cruises USD", currency: "usd", payment_instructions: "Wire to Example Bank\r\nRef: group").record
    assert_equal "USD", account.currency
    assert_equal "Wire to Example Bank\nRef: group", account.payment_instructions

    SavePayeeAccount.new(agency: @agency, actor: agency_users(:harbor_baseline_staff), supplier: @supplier, payee_account: account,
      attributes: { name: "Alpha USD" }, lock_version: account.lock_version).call
    assert_equal "Alpha USD", account.reload.name
    assert_equal %w[supplier.payee_account_added supplier.payee_account_updated],
      AuditEvent.where(subject_id: @supplier.id, action: [ "supplier.payee_account_added", "supplier.payee_account_updated" ]).order(:created_at).pluck(:action)
  end

  test "invalid, duplicate and stale saves are refused" do
    account = save!(name: "Main", currency: "USD").record
    { { name: "", currency: "USD" } => :invalid, { name: "Other", currency: "ZZZ" } => :invalid, { name: "main", currency: "USD" } => :invalid }.each do |attributes, code|
      error = assert_raises(AgencyCommand::Error) { save!(**attributes) }
      assert_equal code, error.code, attributes.inspect
    end
    stale = assert_raises(AgencyCommand::Error) do
      SavePayeeAccount.new(agency: @agency, actor: @admin, supplier: @supplier, payee_account: account, attributes: { name: "X" }, lock_version: account.lock_version + 1).call
    end
    assert_equal :conflict, stale.code
  end

  test "the database refuses a cross-agency supplier" do
    assert_raises(ActiveRecord::StatementInvalid) do
      PayeeAccount.transaction(requires_new: true) do
        PayeeAccount.insert_all!([ { agency_id: agencies(:cove).id, supplier_id: @supplier.id, name: "X", currency: "USD" } ])
      end
    end
  end

  private

  def save!(**attributes)
    SavePayeeAccount.new(agency: @agency, actor: @admin, supplier: @supplier, attributes:).call
  end
end
