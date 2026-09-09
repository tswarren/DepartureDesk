require "test_helper"

class TravelProgramTest < ActiveSupport::TestCase
  test "new programs are active without inactivation metadata" do
    program = create_travel_program!(agencies(:one), actor: users(:one), name: "Wine Country")

    assert program.active?
    assert_nil program.inactivated_at
    assert_nil program.inactivation_reason
  end

  test "database rejects inactive rows without a reason" do
    now = Time.current
    assert_raises(ActiveRecord::StatementInvalid) do
      TravelProgram.transaction(requires_new: true) do
        TravelProgram.insert_all!([
          {
            id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
            agency_id: agencies(:one).id,
            name: "Broken Program",
            status: "inactive",
            lock_version: 0,
            created_at: now,
            updated_at: now
          }
        ])
      end
    end
  end

  test "program names may be reused within an agency" do
    create_travel_program!(agencies(:one), actor: users(:one), name: "Atlantic Series")
    second = create_travel_program!(agencies(:one), actor: users(:one), name: "Atlantic Series")

    assert second.persisted?
  end
end
