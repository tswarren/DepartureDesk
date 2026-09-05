require "test_helper"

class OfficeBackfillTest < ActiveSupport::TestCase
  test "backfill is idempotent for an agency with no offices" do
    agency = Agency.create!(
      name: "Backfill Travel",
      default_timezone: "UTC",
      default_currency: "USD",
      country_code: "US"
    )
    user = User.create!(
      email_address: "backfill-admin@example.com",
      first_name: "Back",
      last_name: "Fill",
      password: "password",
      password_confirmation: "password"
    )
    membership = AgencyMembership.create!(
      user:,
      agency:,
      role: "administrator",
      status: "active"
    )

    2.times { run_backfill }

    assert_equal 1, agency.offices.where(code: "MAIN").count
    office = agency.offices.find_by!(code: "MAIN")
    assert_equal "UTC", office.default_timezone
    assignments = OfficeAssignment.where(agency_membership: membership)
    assert_equal 1, assignments.count
    assert assignments.first.is_default?
    assert assignments.first.active?
  end

  private

  def run_backfill
    Office.connection.execute(<<~SQL)
      INSERT INTO offices (
        id, agency_id, name, code, status, default_timezone, lock_version, created_at, updated_at
      )
      SELECT uuidv7(),
             agencies.id,
             agencies.name,
             'MAIN',
             'active',
             agencies.default_timezone,
             0,
             CURRENT_TIMESTAMP,
             CURRENT_TIMESTAMP
      FROM agencies
      WHERE NOT EXISTS (
        SELECT 1 FROM offices WHERE offices.agency_id = agencies.id
      );

      INSERT INTO office_assignments (
        id, agency_id, agency_membership_id, office_id, status, is_default,
        granted_at, revoked_at, lock_version, created_at, updated_at
      )
      SELECT uuidv7(),
             memberships.agency_id,
             memberships.id,
             offices.id,
             'active',
             TRUE,
             CURRENT_TIMESTAMP,
             NULL,
             0,
             CURRENT_TIMESTAMP,
             CURRENT_TIMESTAMP
      FROM agency_memberships AS memberships
      INNER JOIN offices
        ON offices.agency_id = memberships.agency_id
       AND offices.code = 'MAIN'
      WHERE memberships.status <> 'revoked'
        AND NOT EXISTS (
          SELECT 1
          FROM office_assignments
          WHERE office_assignments.agency_membership_id = memberships.id
        );
    SQL
  end
end
