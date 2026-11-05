require "test_helper"

# DEP-16, DEP-19, DEP-20; charter scope: Proceed only in Slice 1.
class RecordDepartureDecisionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Decide" }).call.record
  end

  test "Proceed is recorded with who, when and an optional note, and keeps the history" do
    travel_to Time.utc(2026, 1, 10, 15) do
      record!(note: "Numbers look good")
    end
    record!(note: "")

    @departure.reload
    assert @departure.decision_proceed?
    assert_equal 2, @departure.decisions.count
    first = @departure.decisions.last
    assert_equal "proceed", first.decision
    assert_equal "Numbers look good", first.note
    assert_equal @admin, first.decided_by
    assert_equal Time.utc(2026, 1, 10, 15), first.decided_at
    assert_nil @departure.decisions.first.note
    assert_equal 2, AuditEvent.where(subject_id: @departure.id, action: "departure.decision_recorded").count
  end

  test "Proceed does not change the sales status or completion" do
    record!
    assert_equal "not_on_sale", @departure.reload.summary_label
  end

  test "only Proceed is accepted in Slice 1, and a note is required for Postpone and Cancel in the database" do
    %w[postpone cancel undecided].each do |decision|
      error = assert_raises(AgencyCommand::Error) { record!(decision:) }
      assert_equal :invalid, error.code
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      DepartureDecision.transaction(requires_new: true) do
        DepartureDecision.insert_all!([ { agency_id: @agency.id, departure_id: @departure.id, decision: "cancel", decided_by_id: @admin.id, decided_at: Time.current, created_at: Time.current } ])
      end
    end
  end

  test "staff without departure management are refused, and a stale form is a conflict" do
    error = assert_raises(AgencyCommand::Error) { record!(actor: agency_users(:harbor_baseline_staff)) }
    assert_equal :unauthorized, error.code
    stale = assert_raises(AgencyCommand::Error) { record!(lock_version: @departure.lock_version + 1) }
    assert_equal :conflict, stale.code
    assert_empty @departure.reload.decisions
  end

  test "decisions are append-only in the model and the database" do
    decision = record!.record
    assert_not decision.update(note: "rewritten")
    assert_not decision.destroy
    assert_raises(ActiveRecord::StatementInvalid) do
      DepartureDecision.transaction(requires_new: true) { DepartureDecision.where(id: decision.id).update_all(note: "x") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      DepartureDecision.transaction(requires_new: true) { DepartureDecision.where(id: decision.id).delete_all }
    end
  end

  private

  def record!(decision: "proceed", note: nil, actor: @admin, lock_version: @departure.reload.lock_version)
    RecordDepartureDecision.new(agency: @agency, actor:, departure: @departure, decision:, note:, lock_version:).call
  end
end
