require "test_helper"

class OfficeAssignmentTest < ActiveSupport::TestCase
  test "database rejects a cross-agency assignment" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      OfficeAssignment.connection.execute(<<~SQL)
        INSERT INTO office_assignments (
          id, agency_id, agency_membership_id, office_id, status, is_default,
          granted_at, lock_version, created_at, updated_at
        )
        VALUES (
          uuidv7(),
          '#{agencies(:one).id}',
          '#{agency_memberships(:one).id}',
          '#{offices(:two).id}',
          'active',
          FALSE,
          CURRENT_TIMESTAMP,
          0,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "database rejects a default on a revoked assignment" do
    assert_raises(ActiveRecord::StatementInvalid) do
      OfficeAssignment.connection.execute(<<~SQL)
        INSERT INTO office_assignments (
          id, agency_id, agency_membership_id, office_id, status, is_default,
          granted_at, revoked_at, lock_version, created_at, updated_at
        )
        VALUES (
          uuidv7(),
          '#{agencies(:one).id}',
          '#{agency_memberships(:one).id}',
          '#{create_extra_office.id}',
          'revoked',
          TRUE,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP,
          0,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  test "database allows only one default assignment per membership" do
    extra = create_extra_office

    assert_raises(ActiveRecord::RecordNotUnique) do
      OfficeAssignment.connection.execute(<<~SQL)
        INSERT INTO office_assignments (
          id, agency_id, agency_membership_id, office_id, status, is_default,
          granted_at, lock_version, created_at, updated_at
        )
        VALUES (
          uuidv7(),
          '#{agencies(:one).id}',
          '#{agency_memberships(:one).id}',
          '#{extra.id}',
          'active',
          TRUE,
          CURRENT_TIMESTAMP,
          0,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  private

  def create_extra_office
    agencies(:one).offices.create!(
      name: "Boston",
      code: "BOS",
      status: "active",
      default_timezone: agencies(:one).default_timezone
    )
  end
end
