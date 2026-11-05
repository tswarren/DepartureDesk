require "test_helper"

# ADR 0017 reseller schema: a reseller user has exactly one same-agency
# reseller relationship, and no other user type has one.
class ResellerSchemaTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @reseller = @agency.resellers.create!(name: "Harbor Partners")
  end

  test "a reseller relationship defaults to active with direct contact allowed (DOC-08)" do
    assert @reseller.active?
    assert @reseller.direct_contact_allowed
    assert_equal Reseller::STATUSES, %w[active booking_paused suspended ended]
  end

  test "a reseller user with a same-agency relationship is valid" do
    user = build_user(user_type: "reseller", reseller: @reseller)
    assert user.save, user.errors.full_messages.to_sentence
    assert user.reseller?
    assert_not user.permitted?(:view_workspace)
  end

  test "the model refuses a reseller without a relationship and staff with one" do
    assert_not build_user(user_type: "reseller").valid?
    assert_not build_user(user_type: "staff", reseller: @reseller).valid?
    other = agencies(:cove).resellers.create!(name: "Cove Partners")
    assert_not build_user(user_type: "reseller", reseller: other).valid?
  end

  test "the database refuses a reseller without a relationship" do
    assert_db_refuses { insert_user(user_type: "reseller", reseller_id: nil) }
  end

  test "the database refuses a staff user or agency admin with a relationship" do
    assert_db_refuses { insert_user(user_type: "staff", reseller_id: @reseller.id) }
    assert_db_refuses { insert_user(user_type: "agency_admin", reseller_id: @reseller.id) }
  end

  test "the database refuses a cross-agency relationship" do
    other = agencies(:cove).resellers.create!(name: "Cove Partners")
    assert_db_refuses { insert_user(user_type: "reseller", reseller_id: other.id) }
  end

  test "the database refuses an unknown status and a blank name" do
    assert_db_refuses { Reseller.where(id: @reseller.id).update_all(status: "paused") }
    assert_db_refuses { Reseller.where(id: @reseller.id).update_all(name: "  ") }
  end

  test "invitations still refuse the reseller type" do
    error = assert_raises(AgencyCommand::Error) do
      InviteAgencyUser.new(
        agency: @agency, actor: agency_users(:harbor_admin),
        email_address: "res@example.com", first_name: "Res", last_name: "Eller", user_type: "reseller"
      ).call
    end
    assert_equal :invalid, error.code
  end

  private

  def build_user(**attributes)
    @agency.agency_users.new(
      email_address: "user-#{SecureRandom.hex(3)}@example.test", first_name: "Res", last_name: "User",
      password: "password12345", status: "active", credential_version: 1, **attributes
    )
  end

  def insert_user(user_type:, reseller_id:)
    AgencyUser.insert_all!([ {
      agency_id: @agency.id, email_address: "raw-#{SecureRandom.hex(3)}@example.test", first_name: "Raw", last_name: "User",
      user_type:, reseller_id:, status: "invited", credential_version: 0
    } ])
  end

  def assert_db_refuses(&block)
    assert_raises(ActiveRecord::StatementInvalid) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end
end
