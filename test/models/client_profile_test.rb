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
      party_status: nil,
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

  test "active profile requires an active party projection" do
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(party: parties(:unlinked), office: offices(:one), now:).merge(party_status: nil)
        ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([
          client_row(party: parties(:unlinked), office: offices(:one), now:).merge(party_status: "deactivated")
        ])
      end
    end
  end

  test "inactive profile cannot keep an active party projection" do
    now = Time.current
    row = client_row(party: parties(:unlinked), office: offices(:one), now:).merge(
      status: "inactive",
      responsible_office_status: nil,
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

  test "an active profile cannot be inserted for a deactivated party" do
    party = parties(:unlinked)
    deactivate_party!(party)
    now = Time.current

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientProfile.transaction(requires_new: true) do
        ClientProfile.insert_all!([ client_row(party:, office: offices(:one), now:) ])
      end
    end
  end

  test "party status cannot become deactivated while an active profile holds the projection" do
    party = parties(:unlinked)
    assign_client_role!(party, actor: users(:one))

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Party.transaction(requires_new: true) do
        Party.connection.execute(<<~SQL.squish)
          UPDATE parties
          SET status = 'deactivated',
              deactivated_at = CURRENT_TIMESTAMP,
              deactivated_by_membership_id = '#{agency_memberships(:one).id}',
              deactivation_reason = 'Left directory'
          WHERE id = '#{party.id}'
        SQL
      end
    end
    assert party.reload.active?
  end

  test "model validation rejects an active profile on a deactivated party" do
    party = parties(:unlinked)
    deactivate_party!(party)

    profile = ClientProfile.new(
      agency: agencies(:one),
      party:,
      party_kind: party.party_kind,
      status: "active",
      party_status: "active",
      responsible_office: offices(:one),
      responsible_office_status: "active"
    )

    assert_not profile.valid?
    assert_includes profile.errors[:party], "must be active"
  end

  private

  def deactivate_party!(party)
    party.update!(
      status: "deactivated",
      deactivated_at: Time.current,
      deactivated_by_membership: agency_memberships(:one),
      deactivation_reason: "Left directory"
    )
  end

  def client_row(party:, office:, now:, party_kind: party.party_kind)
    {
      agency_id: party.agency_id,
      party_id: party.id,
      party_kind:,
      status: "active",
      party_status: "active",
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
