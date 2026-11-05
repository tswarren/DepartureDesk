require "test_helper"

# BKG-21 traveler types on the agency profile (S-02).
class TravelerTypesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
  end

  test "a provisioned agency starts with Adult, Child and Child 0–4" do
    agency = ProvisionAgency.new(
      name: "Types #{SecureRandom.hex(3)}", workspace_code: "t#{SecureRandom.hex(4)}", country_code: "US",
      default_currency: "USD", default_timezone: "UTC", administrator_email: "types@example.test",
      administrator_first_name: "Tia", administrator_last_name: "Types", administrator_password: TEST_PASSWORD,
      actor_identifier: "test:traveler-types"
    ).call.record

    assert_equal [ "Adult", "Child", "Child 0–4" ], agency.traveler_types.ordered.pluck(:name)
    assert agency.traveler_types.all?(&:active?)
  end

  test "an agency admin adds a type at the end with an audit event" do
    assert_difference -> { AuditEvent.where(action: "traveler_type.created").count }, 1 do
      CreateTravelerType.new(agency: @agency, actor: @admin, name: "  Senior  ").call
    end
    assert_equal [ "Adult", "Child", "Child 0–4", "Senior" ], @agency.traveler_types.ordered.pluck(:name)
  end

  test "names are unique within the agency regardless of case" do
    error = assert_raises(AgencyCommand::Error) { CreateTravelerType.new(agency: @agency, actor: @admin, name: "adult").call }
    assert_equal :invalid, error.code
    assert CreateTravelerType.new(agency: agencies(:cove), actor: agency_users(:cove_admin), name: "Senior").call.record.persisted?
  end

  test "inactivating, renaming and reordering are audited and leave the row in place" do
    child = traveler_types(:harbor_child)
    result = UpdateTravelerType.new(
      traveler_type: child, actor: @admin, attributes: { status: "inactive", name: "Youth", position: 5 }, lock_version: child.lock_version
    ).call

    assert_equal :updated, result.status
    child.reload
    assert child.inactive?
    assert_equal "Youth", child.name
    event = AuditEvent.where(action: "traveler_type.updated", subject_id: child.id).sole
    assert_equal %w[name position status], event.details["changed"]

    same = UpdateTravelerType.new(traveler_type: child, actor: @admin, attributes: { name: "Youth" }, lock_version: child.lock_version).call
    assert_equal :noop, same.status
  end

  test "staff cannot change traveler types and stale edits are refused" do
    error = assert_raises(AgencyCommand::Error) do
      CreateTravelerType.new(agency: @agency, actor: agency_users(:harbor_staff), name: "Senior").call
    end
    assert_equal :unauthorized, error.code

    adult = traveler_types(:harbor_adult)
    stale = assert_raises(AgencyCommand::Error) do
      UpdateTravelerType.new(traveler_type: adult, actor: @admin, attributes: { name: "Grown-up" }, lock_version: adult.lock_version + 1).call
    end
    assert_equal :conflict, stale.code
    assert_equal "Adult", adult.reload.name
  end

  test "the database refuses a duplicate name and an unknown status" do
    assert_raises(ActiveRecord::StatementInvalid) do
      TravelerType.transaction(requires_new: true) do
        TravelerType.insert_all!([ { agency_id: @agency.id, name: "ADULT", position: 9, status: "active" } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      TravelerType.transaction(requires_new: true) do
        TravelerType.where(id: traveler_types(:harbor_adult).id).update_all(status: "archived")
      end
    end
  end
end
