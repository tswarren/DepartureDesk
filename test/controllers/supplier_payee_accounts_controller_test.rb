require "test_helper"

class SupplierPayeeAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = CreateSupplier.new(agency: agencies(:harbor), actor: agency_users(:harbor_admin), kind: "organization", names: { display_name: "Payee Host" }, categories: [ "lodging" ]).call.record
  end

  test "staff add a payee account from the supplier page" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get supplier_path(@supplier)
    assert_select "#payee-accounts a", text: "Add"

    post supplier_payee_accounts_path(@supplier), params: { payee_account: { name: "Host USD", currency: "USD", payment_instructions: "ACH" } }
    assert_redirected_to supplier_path(@supplier, anchor: "payee-accounts")
    follow_redirect!
    assert_select "#payee-accounts th", text: "Host USD"

    post supplier_payee_accounts_path(@supplier), params: { payee_account: { name: "", currency: "USD" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
  end

  test "another agency's supplier is not found" do
    sign_in_as agency_users(:cove_admin)
    get new_supplier_payee_account_path(@supplier)
    assert_response :not_found
  end
end
