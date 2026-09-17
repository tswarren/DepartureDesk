require "test_helper"

class SupplierConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-100001",
      display_name: "Harbor Supplier",
      status: "active"
    )
    @other_supplier = @other.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-200001",
      display_name: "Cove Supplier",
      status: "active"
    )
  end

  test "supplier tables exist in the structure" do
    assert_equal %w[
      supplier_arrangement_activation_capacity_entries
      supplier_arrangement_activation_cost_selections
      supplier_arrangement_activations
      supplier_arrangement_versions
      supplier_arrangements
      supplier_category_assignments
      supplier_commitment_trigger_definitions
      supplier_commitments
      supplier_confirmation_activation_links
      supplier_confirmation_capacity_event_links
      supplier_confirmation_commitment_links
      supplier_confirmation_identifier_links
      supplier_confirmations
      supplier_contact_email_addresses
      supplier_contact_phone_numbers
      supplier_contacts
      supplier_cost_component_bases
      supplier_cost_components
      supplier_cost_definitions
      supplier_cost_occupancy_profile_positions
      supplier_cost_occupancy_profiles
      supplier_cost_participant_categories
      supplier_cost_sources
      supplier_cost_usage_assumptions
      supplier_email_addresses
      supplier_issued_identifiers
      supplier_locations
      supplier_phone_numbers
      supplier_postal_addresses
      supplier_reservation_event_scope_outcomes
      supplier_reservation_events
      supplier_reservation_projections
      supplier_reservation_revisions
      supplier_reservation_scopes
      supplier_reservations
      supplier_resource_definitions
      supplier_resources
      supplier_websites
      suppliers
    ], ActiveRecord::Base.connection.tables.grep(/\Asupplier/).sort
  end

  test "name shapes are enforced by Active Record and direct SQL" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @agency.suppliers.create!(
        kind: "organization",
        supplier_reference: "SUP-100002",
        first_name: "Org",
        last_name: "Name",
        status: "active"
      )
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      @agency.suppliers.create!(
        kind: "individual",
        supplier_reference: "SUP-100003",
        display_name: "Person LLC",
        status: "active"
      )
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Supplier.transaction(requires_new: true) do
        Supplier.insert!(supplier_row(
          kind: "organization",
          supplier_reference: "SUP-100004",
          display_name: "Invalid Org",
          first_name: "Ada",
          last_name: nil
        ))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Supplier.transaction(requires_new: true) do
        Supplier.insert!(supplier_row(
          kind: "individual",
          supplier_reference: "SUP-100005",
          display_name: "Invalid Person",
          first_name: "Ada",
          last_name: "Guide"
        ))
      end
    end
  end

  test "unused name columns are stored as null for each kind" do
    organization = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-100006",
      display_name: "Name Shape Org",
      legal_name: "Name Shape LLC",
      first_name: "  ",
      last_name: "",
      status: "active"
    )
    individual = @agency.suppliers.create!(
      kind: "individual",
      supplier_reference: "SUP-100007",
      display_name: " ",
      legal_name: "",
      first_name: "Ada",
      last_name: "Guide",
      status: "active"
    )

    assert_nil organization.first_name
    assert_nil organization.last_name
    assert_nil individual.display_name
    assert_nil individual.legal_name
  end

  test "supplier identity columns are immutable" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Supplier.transaction(requires_new: true) do
        Supplier.where(id: @supplier.id).update_all(kind: "individual")
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Supplier.transaction(requires_new: true) do
        Supplier.where(id: @supplier.id).update_all(supplier_reference: "SUP-999999")
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Supplier.transaction(requires_new: true) do
        Supplier.where(id: @supplier.id).update_all(agency_id: @other.id)
      end
    end
  end

  test "category identity columns are immutable" do
    assignment = @supplier.category_assignments.create!(agency: @agency, category_code: "cruise_line")

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.where(id: assignment.id).update_all(category_code: "lodging")
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.where(id: assignment.id).update_all(supplier_id: @other_supplier.id)
      end
    end
  end

  test "contact point owners are immutable" do
    contact_points = [
      @supplier.email_addresses.create!(agency: @agency, address: "immutable@example.com", status: "active"),
      @supplier.phone_numbers.create!(agency: @agency, number: "202-555-0100", normalized_number: "+12025550100", country_code: "US", status: "active"),
      @supplier.postal_addresses.create!(agency: @agency, line_1: "1 Dock", country_code: "US", status: "active"),
      @supplier.websites.create!(agency: @agency, url: "example.com", normalized_url: "https://example.com", normalized_host: "example.com", status: "active")
    ]

    contact_points.each do |point|
      assert_raises(ActiveRecord::StatementInvalid, point.class.name) do
        point.class.transaction(requires_new: true) do
          point.class.where(id: point.id).update_all(supplier_id: @other_supplier.id)
        end
      end
    end
  end

  test "category codes match migration check and other label nullability" do
    assert_equal checked_category_codes, SupplierCategory::CODES

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.insert!(category_row(category_code: "other", other_label: nil))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.insert!(category_row(category_code: "lodging", other_label: "Hotel"))
      end
    end

    @supplier.category_assignments.create!(agency: @agency, category_code: "other", other_label: "Expedition partner")

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.insert!(category_row(category_code: "other", other_label: " Expedition "))
      end
    end
  end

  test "only one preferred active contact point exists per supplier channel" do
    preferred = [
      [ SupplierEmailAddress, { address: "first@example.com" }, { address: "second@example.com" } ],
      [
        SupplierPhoneNumber,
        { number: "202-555-0101", normalized_number: "+12025550101", country_code: "US" },
        { number: "202-555-0102", normalized_number: "+12025550102", country_code: "US" }
      ],
      [
        SupplierPostalAddress,
        { line_1: "1 Pier", country_code: "US" },
        { line_1: "2 Pier", country_code: "US" }
      ],
      [
        SupplierWebsite,
        { url: "first.example", normalized_url: "https://first.example", normalized_host: "first.example" },
        { url: "second.example", normalized_url: "https://second.example", normalized_host: "second.example" }
      ]
    ]

    preferred.each do |klass, first_attrs, second_attrs|
      klass.create!(agency: @agency, supplier: @supplier, preferred: true, status: "active", **first_attrs)

      assert_raises(ActiveRecord::RecordNotUnique, klass.name) do
        klass.create!(agency: @agency, supplier: @supplier, preferred: true, status: "active", **second_attrs)
      end

      klass.create!(agency: @agency, supplier: @supplier, preferred: true, status: "inactive", **second_attrs.merge(unique_suffix_attrs(klass)))
    end
  end

  test "same-agency foreign keys reject cross-agency supplier pairings" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierCategoryAssignment.transaction(requires_new: true) do
        SupplierCategoryAssignment.insert!(category_row(supplier_id: @other_supplier.id, category_code: "air"))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierEmailAddress.transaction(requires_new: true) do
        SupplierEmailAddress.insert!(contact_row(SupplierEmailAddress, supplier_id: @other_supplier.id, address: "wrong@example.com"))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierPhoneNumber.transaction(requires_new: true) do
        SupplierPhoneNumber.insert!(contact_row(
          SupplierPhoneNumber,
          supplier_id: @other_supplier.id,
          number: "202-555-0103",
          normalized_number: "+12025550103",
          country_code: "US"
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierPostalAddress.transaction(requires_new: true) do
        SupplierPostalAddress.insert!(contact_row(
          SupplierPostalAddress,
          supplier_id: @other_supplier.id,
          line_1: "3 Pier",
          country_code: "US"
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierWebsite.transaction(requires_new: true) do
        SupplierWebsite.insert!(contact_row(
          SupplierWebsite,
          supplier_id: @other_supplier.id,
          url: "wrong.example",
          normalized_url: "https://wrong.example",
          normalized_host: "wrong.example"
        ))
      end
    end
  end

  test "btree_gist remains scoped to client organization contact history" do
    enabled = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT count(*) FROM pg_extension WHERE extname = 'btree_gist'
    SQL
    assert_equal 1, enabled.to_i

    exclusions = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE c.contype = 'x'
      ORDER BY c.conname
    SQL
    assert_equal [ "client_org_contacts_no_overlapping_history" ], exclusions
  end

  private

  def supplier_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      kind: "organization",
      supplier_reference: "SUP-100999",
      display_name: "Inserted Supplier",
      legal_name: nil,
      first_name: nil,
      last_name: nil,
      doing_business_as: nil,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def category_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_id: @supplier.id,
      category_code: "cruise_line",
      other_label: nil,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def contact_row(klass, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      supplier_id: @supplier.id,
      label: nil,
      preferred: false,
      status: "active",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def checked_category_codes
    definition = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT pg_get_constraintdef(c.oid)
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE t.relname = 'supplier_category_assignments'
        AND c.conname = 'supplier_category_assignments_code'
    SQL
    definition.scan(/'([^']+)'::character varying/).flatten
  end

  def unique_suffix_attrs(klass)
    case klass.name
    when "SupplierEmailAddress" then { address: "inactive-#{SecureRandom.hex(3)}@example.com" }
    when "SupplierPhoneNumber"
      digits = rand(10_000..99_999)
      { number: "202-555-#{digits}", normalized_number: "+120255#{digits}", country_code: "US" }
    when "SupplierPostalAddress" then { line_1: "#{rand(10..99)} Inactive Pier", country_code: "US" }
    when "SupplierWebsite"
      host = "inactive-#{SecureRandom.hex(3)}.example"
      { url: host, normalized_url: "https://#{host}", normalized_host: host }
    end
  end
end
