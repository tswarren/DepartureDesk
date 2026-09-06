require "test_helper"

class ClientProfileTest < ActiveSupport::TestCase
  test "household supplier rows are rejected at the database" do
    now = Time.current
    party = parties(:household_one)
    office = offices(:one)

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierProfile.transaction(requires_new: true) do
        SupplierProfile.insert_all!([ supplier_row(party:, office:, party_kind: "household", now:) ])
      end
    end
  end

  test "supplier party_kind mismatch is rejected at the database" do
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierProfile.transaction(requires_new: true) do
        SupplierProfile.insert_all!([
          supplier_row(
            party: parties(:household_one),
            office: offices(:one),
            party_kind: "person",
            now:
          )
        ])
      end
    end
  end

  test "client party_kind mismatch is rejected at the database" do
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(
            party: parties(:unlinked),
            office: offices(:one),
            party_kind: "organization",
            now:
          )
        ])
      end
    end
  end

  test "duplicate party profiles are rejected at the database" do
    assign_client_role!(parties(:unlinked), actor: users(:one))
    now = Time.current

    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([ client_row(party: parties(:unlinked), office: offices(:one), now:) ])
      end
    end
  end

  test "null responsible office is rejected at the database" do
    now = Time.current
    row = client_row(party: parties(:unlinked), office: offices(:one), now:).merge(responsible_office_id: nil)

    assert_raises(ActiveRecord::NotNullViolation) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([ row ])
      end
    end
  end

  test "active profile requires an active office projection" do
    now = Time.current
    row = client_row(party: parties(:unlinked), office: offices(:one), now:).merge(responsible_office_status: nil)

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([ row ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(party: parties(:unlinked), office: offices(:one), now:).merge(responsible_office_status: "inactive")
        ])
      end
    end
  end

  test "inactive profile cannot keep an active office projection" do
    now = Time.current
    row = client_row(party: parties(:unlinked), office: offices(:one), now:).merge(
      status: "inactive",
      deactivated_at: now,
      deactivated_by_membership_id: agency_memberships(:one).id,
      deactivation_reason: "Closed"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([ row ])
      end
    end
  end

  test "cross-agency party and office foreign keys are rejected" do
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(party: parties(:two), office: offices(:one), now:).merge(agency_id: agencies(:one).id)
        ])
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(party: parties(:unlinked), office: offices(:two), now:).merge(agency_id: agencies(:one).id)
        ])
      end
    end
  end

  test "identity columns cannot change after create" do
    profile = assign_client_role!(parties(:unlinked), actor: users(:one))

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.connection.execute(
          "UPDATE client_profiles SET party_kind = 'organization' WHERE id = '#{profile.id}'"
        )
      end
    end
  end

  test "office status cannot become inactive while an active profile holds the projection" do
    assign_client_role!(parties(:unlinked), actor: users(:one), office: offices(:one))
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office

    assert extra.active?
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Office.transaction(requires_new: true) do
        Office.connection.execute(
          "UPDATE offices SET status = 'inactive' WHERE id = '#{offices(:one).id}'"
        )
      end
    end
    assert offices(:one).reload.active?
  end

  private

  def client_row(party:, office:, now:, party_kind: party.party_kind)
    {
      agency_id: party.agency_id,
      party_id: party.id,
      party_kind:,
      status: "active",
      responsible_office_id: office.id,
      responsible_office_status: "active",
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def supplier_row(party:, office:, now:, party_kind: party.party_kind)
    client_row(party:, office:, now:, party_kind:).merge(default_currency: "USD")
  end
end
