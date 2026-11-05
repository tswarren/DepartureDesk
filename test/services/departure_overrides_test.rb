require "test_helper"

# DEP-01, BKG-09, CMN-10, SET-14: optional per-Departure overrides.
class DepartureOverridesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
  end

  test "blank overrides use the agency default and record nothing" do
    departure = create!(name: "Defaults")
    assert_nil departure.hold_duration_days
    assert_nil departure.installment_buffer_days
    assert_equal 2, departure.effective_hold_duration_days
    assert_equal 14, departure.effective_installment_buffer_days

    @agency.update!(hold_duration_days: 3)
    assert_equal 3, departure.reload.effective_hold_duration_days, "a blank override follows the agency"
  end

  test "an override is stored, survives an agency default change, and can be cleared" do
    departure = create!(name: "Overrides", hold_duration_days: "5", installment_buffer_days: "0")
    assert_equal 5, departure.effective_hold_duration_days
    assert_equal 0, departure.effective_installment_buffer_days

    @agency.update!(hold_duration_days: 3, installment_buffer_days: 21)
    assert_equal 5, departure.reload.effective_hold_duration_days

    UpdateDeparture.new(
      agency: @agency, actor: @admin, departure:,
      attributes: { name: "Overrides", hold_duration_days: "", installment_buffer_days: "7" },
      lock_version: departure.lock_version
    ).call
    departure.reload
    assert_nil departure.hold_duration_days
    assert_equal 7, departure.installment_buffer_days
    event = AuditEvent.where(subject_id: departure.id, action: "departure.updated").order(:created_at).last
    assert_includes event.details["changed_fields"], "hold_duration_days"
  end

  test "invalid overrides are refused by the command and the database" do
    [ [ :hold_duration_days, "0" ], [ :installment_buffer_days, "-1" ], [ :hold_duration_days, "2.5" ] ].each do |field, value|
      error = assert_raises(AgencyCommand::Error) { create!(name: "Bad", field => value) }
      assert_equal :invalid, error.code, "#{field}=#{value}"
    end
    departure = create!(name: "Checks")
    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) { Departure.where(id: departure.id).update_all(hold_duration_days: 0) }
    end
  end

  private

  def create!(**attributes)
    CreateDeparture.new(agency: @agency, actor: @admin, attributes:).call.record
  end
end
