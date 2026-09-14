require "test_helper"

class IdentityImmutabilityTest < ActiveSupport::TestCase
  test "the database rejects a workspace code change" do
    assert_identity_rejected(
      "UPDATE agencies SET workspace_code = 'renamed' WHERE id = '#{agencies(:harbor).id}'"
    )
  end

  test "the database rejects moving an agency user to another agency" do
    assert_identity_rejected(
      "UPDATE agency_users SET agency_id = '#{agencies(:cove).id}' WHERE id = '#{agency_users(:harbor_invited).id}'"
    )
  end

  test "the database rejects an office tenancy change" do
    assert_identity_rejected(
      "UPDATE offices SET agency_id = '#{agencies(:cove).id}' WHERE id = '#{offices(:harbor_main).id}'"
    )
  end

  test "the database rejects an office code change" do
    assert_identity_rejected(
      "UPDATE offices SET code = 'RENAMED' WHERE id = '#{offices(:harbor_main).id}'"
    )
  end

  test "the database rejects an email that is not already normalized" do
    assert_identity_rejected(
      "UPDATE agency_users SET email_address = 'Sam@Example.com' WHERE id = '#{agency_users(:harbor_staff).id}'"
    )
  end

  private

  def assert_identity_rejected(sql)
    assert_raises(ActiveRecord::StatementInvalid) do
      Agency.connection.execute(sql)
    end
  end
end
