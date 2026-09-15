require "test_helper"

class SupplierLocationsAndContactsConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-110001",
      display_name: "Harbor Location Supplier",
      status: "active"
    )
    @other_supplier = @other.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-210001",
      display_name: "Cove Location Supplier",
      status: "active"
    )
    @same_agency_other = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-110002",
      display_name: "Harbor Other Supplier",
      status: "active"
    )
  end

  test "same-agency composite foreign keys reject cross-agency pairings" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierLocation.transaction(requires_new: true) do
        SupplierLocation.insert!(location_row(supplier_id: @other_supplier.id, name: "Wrong Agency Pier"))
      end
    end

    contact_id = SecureRandom.uuid_v7
    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierContact.transaction(requires_new: true) do
        SupplierContact.insert!(contact_row(id: contact_id, supplier_id: @other_supplier.id))
      end
    end

    contact = @supplier.contacts.create!(
      agency: @agency,
      first_name: "Pat",
      last_name: "Guide",
      status: "active"
    )
    other_contact = @other_supplier.contacts.create!(
      agency: @other,
      first_name: "Cove",
      last_name: "Guide",
      status: "active"
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierContactEmailAddress.transaction(requires_new: true) do
        SupplierContactEmailAddress.insert!(email_row(supplier_contact_id: other_contact.id, address: "wrong@example.com"))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierContactPhoneNumber.transaction(requires_new: true) do
        SupplierContactPhoneNumber.insert!(phone_row(
          supplier_contact_id: other_contact.id,
          number: "202-555-0190",
          normalized_number: "+12025550190"
        ))
      end
    end

    assert_equal contact.agency_id, @agency.id
  end

  test "location and contact owners are immutable through direct SQL" do
    location = @supplier.locations.create!(
      agency: @agency,
      name: "Immutable Pier",
      status: "active"
    )
    contact = @supplier.contacts.create!(
      agency: @agency,
      first_name: "Immutable",
      last_name: "Contact",
      status: "active"
    )
    email = contact.email_addresses.create!(
      agency: @agency,
      address: "immutable-contact@example.com",
      status: "active"
    )
    phone = contact.phone_numbers.create!(
      agency: @agency,
      number: "202-555-0191",
      normalized_number: "+12025550191",
      country_code: "US",
      status: "active"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierLocation.transaction(requires_new: true) do
        SupplierLocation.where(id: location.id).update_all(supplier_id: @same_agency_other.id)
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierContact.transaction(requires_new: true) do
        SupplierContact.where(id: contact.id).update_all(supplier_id: @same_agency_other.id)
      end
    end

    other_contact = @same_agency_other.contacts.create!(
      agency: @agency,
      first_name: "Other",
      last_name: "Owner",
      status: "active"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierContactEmailAddress.transaction(requires_new: true) do
        SupplierContactEmailAddress.where(id: email.id).update_all(supplier_contact_id: other_contact.id)
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierContactPhoneNumber.transaction(requires_new: true) do
        SupplierContactPhoneNumber.where(id: phone.id).update_all(supplier_contact_id: other_contact.id)
      end
    end
  end

  test "location postal shape phone shape and unit separator are enforced" do
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierLocation.transaction(requires_new: true) do
        SupplierLocation.insert!(location_row(
          name: "Country Only",
          address_country_code: "US"
        ))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierLocation.transaction(requires_new: true) do
        SupplierLocation.insert!(location_row(
          name: "Incomplete Phone",
          phone_number: "202-555-0192"
        ))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierLocation.transaction(requires_new: true) do
        SupplierLocation.insert!(location_row(
          name: "Unit Separator",
          address_line_1: "1#{SupplierLocation::UNIT_SEPARATOR}Dock",
          address_country_code: "US"
        ))
      end
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      @supplier.locations.create!(
        agency: @agency,
        name: "AR Unit Separator",
        address_line_1: "2#{SupplierLocation::UNIT_SEPARATOR}Dock",
        address_country_code: "US",
        status: "active"
      )
    end
  end

  test "only one preferred active contact exists per supplier" do
    first = @supplier.contacts.create!(
      agency: @agency,
      first_name: "First",
      last_name: "Preferred",
      preferred: true,
      status: "active"
    )
    assert first.preferred?

    assert_raises(ActiveRecord::RecordNotUnique) do
      @supplier.contacts.create!(
        agency: @agency,
        first_name: "Second",
        last_name: "Preferred",
        preferred: true,
        status: "active"
      )
    end

    @supplier.contacts.create!(
      agency: @agency,
      first_name: "Inactive",
      last_name: "Preferred",
      preferred: true,
      status: "inactive"
    )
  end

  test "only one preferred active destination exists per contact channel" do
    contact = @supplier.contacts.create!(
      agency: @agency,
      first_name: "Channel",
      last_name: "Preferred",
      status: "active"
    )

    contact.email_addresses.create!(
      agency: @agency,
      address: "first-dest@example.com",
      preferred: true,
      status: "active"
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      contact.email_addresses.create!(
        agency: @agency,
        address: "second-dest@example.com",
        preferred: true,
        status: "active"
      )
    end
    contact.email_addresses.create!(
      agency: @agency,
      address: "inactive-dest@example.com",
      preferred: true,
      status: "inactive"
    )

    contact.phone_numbers.create!(
      agency: @agency,
      number: "202-555-0193",
      normalized_number: "+12025550193",
      country_code: "US",
      preferred: true,
      status: "active"
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      contact.phone_numbers.create!(
        agency: @agency,
        number: "202-555-0194",
        normalized_number: "+12025550194",
        country_code: "US",
        preferred: true,
        status: "active"
      )
    end
  end

  test "M1D directory tables omit office_id" do
    %w[
      supplier_locations
      supplier_contacts
      supplier_contact_email_addresses
      supplier_contact_phone_numbers
    ].each do |table|
      columns = ActiveRecord::Base.connection.columns(table).map(&:name)
      assert_not_includes columns, "office_id", table
    end
  end

  private

  def location_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_id: @supplier.id,
      name: "Inserted Location",
      timezone: nil,
      address_line_1: nil,
      address_line_2: nil,
      address_locality: nil,
      address_region: nil,
      address_postal_code: nil,
      address_country_code: nil,
      phone_number: nil,
      phone_normalized_number: nil,
      phone_extension: nil,
      phone_country_code: nil,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def contact_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_id: @supplier.id,
      first_name: "Inserted",
      last_name: "Contact",
      title: nil,
      department: nil,
      role_label: nil,
      preferred: false,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def email_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_contact_id: attrs[:supplier_contact_id],
      address: "inserted@example.com",
      label: nil,
      preferred: false,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def phone_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_contact_id: attrs[:supplier_contact_id],
      number: "202-555-0199",
      normalized_number: "+12025550199",
      extension: nil,
      country_code: "US",
      label: nil,
      preferred: false,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end
end
