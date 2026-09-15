require "test_helper"

class SuppliersDirectoryTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    ensure_supplier_sequence!(@agency)
    ensure_supplier_sequence!(agencies(:cove))
  end

  test "admin creates an organization supplier" do
    sign_in_as @admin

    assert_difference -> { @agency.suppliers.count }, 1 do
      post suppliers_path, params: {
        supplier: {
          kind: "organization",
          display_name: "Atomic Cruise Line",
          legal_name: "Atomic Cruise Line LLC",
          doing_business_as: "",
          category_codes: [ "cruise_line" ]
        }
      }
    end

    supplier = @agency.suppliers.find_by!(display_name: "Atomic Cruise Line")
    assert_redirected_to supplier_path(supplier)
    assert_equal "SUP-000001", supplier.supplier_reference
    assert_equal [ "cruise_line" ], supplier.category_assignments.pluck(:category_code)
  end

  test "contact points expose set primary and update through route" do
    supplier = create_supplier("Preferred Supplier")
    email = CreateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { address: "row@example.com" }
    ).call.record

    sign_in_as @admin
    get supplier_path(supplier)
    assert_response :success
    assert_select "button", text: "Set primary"

    post set_primary_supplier_email_address_path(supplier, email), params: { lock_version: email.lock_version }
    assert_redirected_to supplier_path(supplier)
    assert email.reload.preferred?
  end

  test "viewer sees supplier identity and categories but not destinations" do
    supplier = create_supplier("Visible Supplier")
    CreateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { address: "hidden-supplier@example.com" }
    ).call

    sign_in_as @viewer
    get supplier_path(supplier)
    assert_response :success
    assert_match "Visible Supplier", response.body
    assert_match "Air", response.body
    assert_no_match "hidden-supplier@example.com", response.body
    assert_select "th", text: "Destination", count: 0
  end

  test "cross-agency supplier is not found on get and patch" do
    other_agency = agencies(:cove)
    supplier = create_supplier("Cove Supplier", agency: other_agency, actor: agency_users(:cove_admin))

    sign_in_as @admin
    get supplier_path(supplier)
    assert_response :not_found

    patch supplier_path(supplier), params: {
      supplier: {
        display_name: "Hijacked",
        legal_name: "",
        doing_business_as: "",
        lock_version: supplier.lock_version
      }
    }
    assert_response :not_found
    assert_equal "Cove Supplier", supplier.reload.display_name
  end

  test "website form uses a text field and schemeless create succeeds" do
    supplier = create_supplier("Website Form Supplier")

    sign_in_as @admin
    get new_supplier_website_path(supplier)
    assert_response :success
    assert_select "input[name='supplier_website[url]'][type=text]"
    assert_select "input[name='supplier_website[url]'][type=url]", count: 0

    assert_difference -> { supplier.websites.count }, 1 do
      post supplier_websites_path(supplier), params: {
        supplier_website: { url: "example.com", label: "Home" }
      }
    end
    assert_redirected_to supplier_path(supplier)
    website = supplier.websites.last
    assert_equal "example.com", website.url
    assert_equal "https://example.com", website.normalized_url
    assert_equal "example.com", website.normalized_host
  end

  test "categories edit updates selected category codes" do
    supplier = create_supplier("Category Edit Supplier")

    sign_in_as @admin
    get categories_edit_supplier_path(supplier)
    assert_response :success
    assert_select "input[name='supplier[category_codes][]'][value=air][checked=checked]"

    patch categories_supplier_path(supplier), params: {
      lock_version: supplier.lock_version,
      supplier: {
        category_codes: [ "lodging", "other" ],
        categories: {
          "0" => { category_code: "other", other_label: "Expedition partner" }
        }
      }
    }
    assert_redirected_to supplier_path(supplier)
    assert_equal %w[lodging other], supplier.category_assignments.order(:category_code).pluck(:category_code)
    assert_equal "Expedition partner", supplier.category_assignments.find_by!(category_code: "other").other_label
  end

  private

  def create_supplier(name, agency: @agency, actor: @admin)
    CreateSupplier.new(
      agency: agency,
      actor: actor,
      kind: "organization",
      names: { display_name: name },
      categories: [ "air" ]
    ).call.record
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
