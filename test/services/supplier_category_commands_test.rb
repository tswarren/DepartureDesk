require "test_helper"

class SupplierCategoryCommandsTest < ActiveSupport::TestCase
  test "adds and removes a category and writes audit without keeping the join row" do
    party = parties(:organization_one)
    profile = assign_supplier_role!(party, actor: users(:one))

    AssignSupplierServiceCategory.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      category_code: "cruise"
    ).call
    assert_equal [ "cruise" ], profile.reload.category_codes
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.supplier_service_category_assigned"

    RemoveSupplierServiceCategory.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      category_code: "cruise"
    ).call
    assert_equal [], profile.reload.category_codes
    assert_equal 0, SupplierServiceCategoryAssignment.where(supplier_profile: profile).count
    event = agencies(:one).audit_events.where(action: "directory.supplier_service_category_removed").order(:created_at).last
    assert_equal "cruise", event.details["category_code"]
    assert_equal "SupplierServiceCategoryAssignment", event.subject_type
  end

  test "duplicate category assignment is a conflict" do
    party = parties(:organization_one)
    profile = assign_supplier_role!(party, actor: users(:one))
    AssignSupplierServiceCategory.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      category_code: "air"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      AssignSupplierServiceCategory.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        category_code: "air"
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "UpdateSupplierProfile persists defaults and cannot change status" do
    party = parties(:organization_one)
    profile = assign_supplier_role!(party, actor: users(:one))

    UpdateSupplierProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      office: offices(:one),
      default_currency: "CAD",
      portal_url: "https://partners.example.com/login",
      booking_instructions: "Request group space 60 days out."
    ).call
    profile.reload
    assert profile.active?
    assert_equal "CAD", profile.default_currency
    assert_equal "https://partners.example.com/login", profile.portal_url
    assert_equal "Request group space 60 days out.", profile.booking_instructions
    event = agencies(:one).audit_events.where(action: "directory.supplier_profile_updated").order(:created_at).last
    assert_includes event.details["changed_fields"], "booking_instructions"
    assert_not_includes event.details.to_s, "Request group space"
  end

  test "portal urls cannot include credentials" do
    party = parties(:organization_one)
    profile = assign_supplier_role!(party, actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      UpdateSupplierProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        office: offices(:one),
        portal_url: "https://user:secret@example.com"
      ).call
    end
    assert_equal :invalid, error.code
    assert_nil profile.reload.portal_url
  end

  test "an organization contact is not a supplier" do
    relationship = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_contact"
    ).call.relationship
    assign_supplier_role!(parties(:organization_one), actor: users(:one))

    assert relationship.record_valid?
    assert_nil parties(:maria).reload.supplier_profile
    assert parties(:organization_one).reload.supplier_profile.active?
  end

  test "an ended relationship cannot receive a purpose" do
    today = DirectoryDate.today(agencies(:one))
    relationship = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_contact",
      effective_from: today - 7
    ).call.relationship
    EndPartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      relationship:,
      inclusive_end_on: today - 1,
      reason: "Left the hotel"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      AssignRelationshipPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship: relationship.reload,
        purpose: "booking",
        priority: 1
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/ended relationship/i, error.message)
  end
end
