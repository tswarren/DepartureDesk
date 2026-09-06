require "test_helper"

module Directory
  class SuppliersControllerTest < ActionDispatch::IntegrationTest
    test "lists suppliers agency-wide and uses a live primary nav link" do
      sign_in_as(users(:one))
      assign_supplier_role!(parties(:organization_one), actor: users(:one), office: offices(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Boston",
        code: "BOS",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }
      assert_redirected_to root_url

      get directory_suppliers_path
      assert_response :success
      assert_includes response.body, parties(:organization_one).display_name
      assert_select "nav[aria-label='Primary navigation'] a[href=?]", directory_suppliers_path, text: "Suppliers"
      assert_select "nav[aria-label='Primary navigation'] a", text: "Clients", count: 0
      assert_nil parties(:maria).supplier_profile
      assert_not_includes response.body, parties(:two).display_name
    end

    test "directory index links to the supplier directory" do
      sign_in_as(users(:one))

      get directory_parties_path
      assert_response :success
      assert_select "a[href=?]", directory_suppliers_path, text: "Suppliers"
    end

    test "cross-agency office filters return not found" do
      sign_in_as(users(:one))

      get directory_suppliers_path, params: { office_id: offices(:two).id }
      assert_response :not_found
    end

    test "derived booking contacts appear without making the person a supplier" do
      sign_in_as(users(:one))
      profile = assign_supplier_role!(parties(:organization_one), actor: users(:one))
      relationship = CreatePartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        origin_party: parties(:maria),
        related_party: parties(:organization_one),
        relationship_kind: "organization_contact"
      ).call.relationship
      AssignRelationshipPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship:,
        purpose: "booking",
        priority: 1
      ).call

      get directory_suppliers_path
      assert_response :success
      assert_includes response.body, "Maria Ruiz"
      assert_nil parties(:maria).reload.supplier_profile
      assert_equal 1, SupplierProfile.where(party_id: parties(:organization_one).id).count
      assert profile.reload.active?
    end
  end
end
