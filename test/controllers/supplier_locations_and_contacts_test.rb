require "test_helper"

class SupplierLocationsAndContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    ensure_supplier_sequence!(@agency)
    ensure_supplier_sequence!(agencies(:cove))
  end

  test "staff can create a location and a contact" do
    supplier = create_supplier("Staff Nested Host")
    sign_in_as @staff

    assert_difference -> { supplier.locations.count }, 1 do
      post supplier_locations_path(supplier), params: {
        supplier_location: {
          name: "Staff Pier",
          timezone: "America/New_York",
          address_line_1: "1 Staff Way",
          address_country_code: "US"
        }
      }
    end
    location = supplier.locations.find_by!(name: "Staff Pier")
    assert_redirected_to supplier_location_path(supplier, location)

    assert_difference -> { supplier.contacts.count }, 1 do
      post supplier_contacts_path(supplier), params: {
        supplier_contact: {
          first_name: "Staff",
          last_name: "Contact",
          title: "Manager"
        }
      }
    end
    contact = supplier.contacts.find_by!(first_name: "Staff", last_name: "Contact")
    assert_redirected_to supplier_contact_path(supplier, contact)
  end

  test "viewer can show a location without address or phone and contact paths are not found" do
    supplier = create_supplier("Viewer Nested Host")
    location = CreateSupplierLocation.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: {
        name: "Visible Pier",
        address_line_1: "99 Hidden Ave",
        address_locality: "Boston",
        address_country_code: "US",
        phone_number: "617-555-0199",
        phone_country_code: "US"
      }
    ).call.record
    contact = CreateSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { first_name: "Hidden", last_name: "Contact" }
    ).call.record

    sign_in_as @viewer
    get supplier_location_path(supplier, location)
    assert_response :success
    assert_match "Visible Pier", response.body
    assert_no_match "99 Hidden Ave", response.body
    assert_no_match "Boston", response.body
    assert_no_match "617-555-0199", response.body

    get supplier_contact_path(supplier, contact)
    assert_response :not_found

    get supplier_path(supplier)
    assert_response :success
    assert_no_match "Hidden Contact", response.body
  end

  test "supplier status confirmation inventory includes locations contacts and destinations" do
    supplier = create_supplier("Impact Host")
    CreateSupplierLocation.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { name: "Impact Pier" }
    ).call
    contact = CreateSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { first_name: "Impact", last_name: "Person" }
    ).call.record
    CreateSupplierEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { address: "impact-supplier@example.com" }
    ).call
    CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { address: "impact-contact@example.com" }
    ).call

    sign_in_as @admin
    get status_edit_supplier_path(supplier)
    assert_response :success
    assert_match "Locations", response.body
    assert_match "Impact Pier", response.body
    assert_match "Contacts", response.body
    assert_match "Impact Person", response.body
    assert_match "Supplier destinations", response.body
    assert_match "impact-supplier@example.com", response.body
    assert_match "Contact destinations", response.body
    assert_match "impact-contact@example.com", response.body
  end

  test "index mixed result kinds link to supplier location and contact profiles" do
    supplier = create_supplier("Index Mix Host")
    location = CreateSupplierLocation.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { name: "Index Mix Pier" }
    ).call.record
    contact = CreateSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { first_name: "Index", last_name: "Mix" }
    ).call.record

    sign_in_as @admin
    get suppliers_path(q: "Index Mix")
    assert_response :success
    assert_select "a[href=?]", supplier_path(supplier), text: "Index Mix Host"
    assert_select "a[href=?]", supplier_location_path(supplier, location), text: "Index Mix Pier"
    assert_select "a[href=?]", supplier_contact_path(supplier, contact), text: "Index Mix"
  end

  test "set_primary marks a contact destination without changing preferred contact" do
    supplier = create_supplier("Primary Dest Host")
    contact = CreateSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      attributes: { first_name: "Primary", last_name: "Dest" }
    ).call.record
    SetPreferredSupplierContact.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      preferred: true,
      lock_version: contact.lock_version
    ).call
    first = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact.reload,
      attributes: { address: "first-dest@example.com", preferred: true }
    ).call.record
    second = CreateSupplierContactEmailAddress.new(
      agency: @agency,
      actor: @admin,
      supplier: supplier,
      supplier_contact: contact,
      attributes: { address: "second-dest@example.com" }
    ).call.record

    sign_in_as @admin
    post set_primary_supplier_contact_email_address_path(supplier, contact, second),
      params: { lock_version: second.lock_version }
    assert_redirected_to supplier_contact_path(supplier, contact)
    assert second.reload.preferred?
    assert_not first.reload.preferred?
    assert contact.reload.preferred?
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
