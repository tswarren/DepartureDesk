require "test_helper"

class SupplierServiceCategoryAssignmentTest < ActiveSupport::TestCase
  test "duplicate category assignments are rejected" do
    profile = assign_supplier_role!(parties(:organization_one), actor: users(:one))
    now = Time.current
    SupplierServiceCategoryAssignment.insert_all!([ category_row(profile:, code: "accommodation", now:) ])

    assert_raises(ActiveRecord::RecordNotUnique) do
      SupplierServiceCategoryAssignment.transaction(requires_new: true) do
        SupplierServiceCategoryAssignment.insert_all!([ category_row(profile:, code: "accommodation", now:) ])
      end
    end
  end

  test "unknown category codes are rejected" do
    profile = assign_supplier_role!(parties(:organization_one), actor: users(:one))
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierServiceCategoryAssignment.transaction(requires_new: true) do
        SupplierServiceCategoryAssignment.insert_all!([ category_row(profile:, code: "other", now:) ])
      end
    end
  end

  test "http portal urls are rejected at the database" do
    now = Time.current
    row = supplier_row(party: parties(:organization_one), office: offices(:one), now:).merge(portal_url: "http://example.com")

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierProfile.transaction(requires_new: true) do
        SupplierProfile.insert_all!([ row ])
      end
    end
  end

  test "portal urls with userinfo are rejected at the database" do
    now = Time.current
    row = supplier_row(party: parties(:organization_one), office: offices(:one), now:).merge(portal_url: "https://user:pass@example.com/portal")

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierProfile.transaction(requires_new: true) do
        SupplierProfile.insert_all!([ row ])
      end
    end
  end

  private

  def category_row(profile:, code:, now:)
    {
      agency_id: profile.agency_id,
      supplier_profile_id: profile.id,
      category_code: code,
      created_at: now,
      updated_at: now
    }
  end

  def supplier_row(party:, office:, now:, party_kind: party.party_kind)
    {
      agency_id: party.agency_id,
      party_id: party.id,
      party_kind:,
      status: "active",
      party_status: "active",
      responsible_office_id: office.id,
      responsible_office_status: "active",
      default_currency: "USD",
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end
end
