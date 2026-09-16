require "test_helper"

class SupplierDirectoryModelsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @sequence = @agency.reference_sequences.find_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE)
    @sequence.update!(next_value: 1)
  end

  test "supplier directory tables omit office_id" do
    %w[
      suppliers
      supplier_category_assignments
      supplier_email_addresses
      supplier_phone_numbers
      supplier_postal_addresses
      supplier_websites
    ].each do |table|
      assert_not Supplier.connection.columns(table).map(&:name).include?("office_id"), table
    end
  end

  test "supplier names match kind shape and directory display prefers dba" do
    organization = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-000001",
      display_name: "  Harbor Cruises  ",
      legal_name: "  ",
      doing_business_as: "  Harbor Sailings  ",
      status: "active"
    )
    individual = @agency.suppliers.create!(
      kind: "individual",
      supplier_reference: "SUP-000002",
      first_name: "  Ada  ",
      last_name: "  Guide  ",
      status: "active"
    )

    assert_nil organization.legal_name
    assert_equal "Harbor Sailings", organization.display_name_for_directory
    assert_equal "Ada Guide", individual.display_name_for_directory

    assert_not @agency.suppliers.build(kind: "organization", supplier_reference: "SUP-000003", first_name: "Org", last_name: "Name").valid?
    assert_not @agency.suppliers.build(kind: "individual", supplier_reference: "SUP-000004", display_name: "Individual LLC").valid?
  end

  test "category catalog normalizes codes and assignments validate other label shape" do
    assert_equal [ "air", "lodging" ], SupplierCategory.normalize_codes([ "lodging", "air", "air", nil, "" ])
    assert_raises(ArgumentError) { SupplierCategory.normalize_codes([ "spaceport" ]) }

    supplier = create_supplier!("SUP-000005")
    supplier.category_assignments.create!(agency: @agency, category_code: "other", other_label: "  Expedition partner  ")
    supplier.category_assignments.create!(agency: @agency, category_code: "air")

    assert_equal %w[air other], supplier.category_assignments.order(:category_code).pluck(:category_code)
    assert_not supplier.category_assignments.build(agency: @agency, category_code: "other").valid?
    assert_not supplier.category_assignments.build(agency: @agency, category_code: "lodging", other_label: "Hotel").valid?
  end

  test "supplier contact points validate and list preferred first" do
    supplier = create_supplier!("SUP-000006")
    later = supplier.email_addresses.create!(agency: @agency, address: "later@example.com", preferred: false, status: "active")
    preferred = supplier.email_addresses.create!(agency: @agency, address: "preferred@example.com", preferred: true, status: "active")

    assert_equal [ preferred, later ], supplier.email_addresses.preferred_first.to_a
    assert_raises(ActiveRecord::RecordInvalid) do
      supplier.email_addresses.create!(agency: @agency, address: "long@example.com", label: "l" * 41, status: "active")
    end
  end

  test "same-agency foreign keys reject cross-agency supplier contact points" do
    supplier = @other.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-000007",
      display_name: "Cove Cruises",
      status: "active"
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierEmailAddress.insert!({
        id: SecureRandom.uuid_v7,
        agency_id: @agency.id,
        supplier_id: supplier.id,
        address: "wrong-agency@example.com",
        preferred: false,
        status: "active",
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "supplier reference issuance uses supplier namespace" do
    issuer = Class.new do
      include SupplierReferenceIssuance

      def call(agency)
        issue_supplier_reference!(agency)
      end
    end.new

    assert_equal "SUP-000001", issuer.call(@agency)
    assert_equal 2, @sequence.reload.next_value
  end

  test "agency provisioning creates client and supplier reference sequences" do
    agency = ProvisionAgency.new(
      name: "Supplier Sequence #{SecureRandom.hex(3)}",
      workspace_code: "sup#{SecureRandom.hex(3)}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Supplier Office",
      office_code: "SUP",
      office_timezone: "UTC",
      administrator_email: "supplier-sequence@example.com",
      administrator_first_name: "Sequence",
      administrator_last_name: "Admin",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:supplier-sequence"
    ).call.record

    assert_equal(
      [
        ReferenceSequence::CLIENT_NAMESPACE,
        ReferenceSequence::DEPARTURE_NAMESPACE,
        ReferenceSequence::SUPPLIER_NAMESPACE
      ],
      agency.reference_sequences.order(:namespace).pluck(:namespace)
    )
  end

  test "supplier audit subjects are accepted only for the same agency" do
    supplier = create_supplier!("SUP-000008")
    other_supplier = @other.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-000009",
      display_name: "Other Supplier",
      status: "active"
    )

    event = RecordAdministrativeAudit.record(
      agency: @agency,
      action: "supplier.created",
      subject: supplier,
      actor_agency_user: agency_users(:harbor_admin),
      details: { "supplier_id" => supplier.id }
    )
    assert_equal "Supplier", event.subject_type

    assert_raises(AgencyCommand::Error) do
      RecordAdministrativeAudit.record(
        agency: @agency,
        action: "supplier.created",
        subject: other_supplier,
        actor_agency_user: agency_users(:harbor_admin),
        details: { "supplier_id" => other_supplier.id }
      )
    end
  end

  private

  def create_supplier!(reference)
    @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: reference,
      display_name: "Harbor Supplier #{reference}",
      status: "active"
    )
  end
end
