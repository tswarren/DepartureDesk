require "test_helper"

# SUP-12, INV-05, INV-10, INV-26, INV-38, ADR 0018 and D-88.
class ConfirmAndCapacityTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Ledger", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Ledger Supplier" }, categories: [ "cruise_line" ]).call.record
    payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier:, attributes: { name: "USD", currency: "USD" }).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id,
      attributes: { group_reference: "GRP-1", payee_account_id: payee.id }).call.record
    dates = { starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York" }
    @cabins = group!(label: "V01", service_category: "cruise", quantity: "8", positions_per_unit: "3", **dates)
    @pool = group!(label: "Nov 4 GQ", service_category: "hotel", representation: "capacity_pool", quantity: "2", **dates)
    @on_request = group!(label: "Nov 1 GQ", service_category: "hotel", representation: "capacity_pool", availability_promise: "on_request", **dates)
  end

  test "Confirm creates shells and pools with opening events, and nothing before it (SUP-12)" do
    assert_equal 0, UnitShell.where(inventory_group: @cabins).count
    assert_nil @pool.reload.capacity_pool

    confirm!
    @arrangement.reload
    assert @arrangement.confirmed?
    shells = @cabins.reload.unit_shells
    assert_equal 8, shells.size
    assert_equal %w[V01-01 V01-08], [ shells.first.label, shells.last.label ]
    assert shells.all? { |shell| shell.positions == 3 && shell.status == "available" }
    assert_equal 8, @cabins.capacity_projection.current_supplier_capacity
    assert_equal 2, @pool.reload.capacity_projection.current_supplier_capacity
    assert @on_request.reload.capacity_pool, "an On request pool exists but holds no number"
    assert_nil @on_request.capacity_projection
    assert_empty @on_request.capacity_events
    assert_equal 8, AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.confirmed").sole.details["shells_created"]
  end

  test "Confirm is refused while blockers remain, and needs a confirmation date" do
    @cabins.update_columns(quantity: nil)
    error = assert_raises(AgencyCommand::Error) { confirm! }
    assert_match(/how many units/, error.message)
    @cabins.update_columns(quantity: 8)
    dateless = assert_raises(AgencyCommand::Error) { confirm!(confirmed_on: "") }
    assert_match(/date the supplier confirmed/, dateless.message)
    assert @arrangement.reload.draft?
  end

  test "an increase adds shells or places, and a supplier release returns a shell or places" do
    confirm!
    IncreaseCapacity.new(**context(@cabins), quantity: "2", evidence_note: "Supplier added two cabins").call
    assert_equal 10, @cabins.reload.unit_shells.count
    assert_equal 10, @cabins.capacity_projection.reload.current_supplier_capacity

    shell = @cabins.unit_shells.last
    RecordSupplierRelease.new(**context(@cabins), unit_shell_id: shell.id, evidence_note: "Supplier took V01-10 back").call
    assert_equal "returned", shell.reload.status
    assert_equal 9, @cabins.capacity_projection.reload.current_supplier_capacity
    again = assert_raises(AgencyCommand::Error) { RecordSupplierRelease.new(**context(@cabins), unit_shell_id: shell.id, evidence_note: "again").call }
    assert_equal :invalid_state, again.code

    RecordSupplierRelease.new(**context(@pool), quantity: "1", evidence_note: "Released one").call
    assert_equal 1, @pool.reload.capacity_projection.current_supplier_capacity
    below = assert_raises(AgencyCommand::Error) { RecordSupplierRelease.new(**context(@pool), quantity: "5", evidence_note: "too many").call }
    assert_match(/below zero/, below.message)
  end

  test "a future-dated release applies at 11:59 p.m. agency time on its date (D-88)" do
    confirm!
    event = RecordSupplierRelease.new(**context(@pool), quantity: "1", effective_on: "2027-03-01", evidence_note: "Release date").call.record
    assert_equal Time.utc(2027, 3, 2, 4, 59), event.applies_at
    assert_equal "America/New_York", event.effective_time_zone
    projection = @pool.reload.capacity_projection
    assert_equal 2, projection.current_supplier_capacity
    assert_equal event.applies_at, projection.next_applies_at
  end

  test "a correction names the event it corrects; a resubmitted form records nothing twice" do
    confirm!
    opening = @pool.reload.capacity_events.sole
    first = CorrectCapacity.new(**context(@pool), direction: "up", quantity: "1", corrects_event_id: opening.id, evidence_note: "Contract said 3", idempotency_key: "form-1").call
    replay = CorrectCapacity.new(**context(@pool), direction: "up", quantity: "1", corrects_event_id: opening.id, evidence_note: "Contract said 3", idempotency_key: "form-1").call
    assert_equal :noop, replay.status
    assert_equal first.record, replay.record
    assert_equal 3, @pool.capacity_projection.reload.current_supplier_capacity
    shell_correction = assert_raises(AgencyCommand::Error) do
      CorrectCapacity.new(**context(@cabins), direction: "up", quantity: "1", corrects_event_id: @cabins.capacity_events.first.id, evidence_note: "x").call
    end
    assert_equal :invalid_state, shell_correction.code
  end

  test "events are append-only, and On request groups refuse numeric events, in the database" do
    confirm!
    event = @pool.reload.capacity_events.sole
    assert_raises(ActiveRecord::StatementInvalid) { CapacityEvent.transaction(requires_new: true) { CapacityEvent.where(id: event.id).update_all(quantity: 5) } }
    assert_raises(ActiveRecord::StatementInvalid) { CapacityEvent.transaction(requires_new: true) { CapacityEvent.where(id: event.id).delete_all } }
    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.insert_all!([ event.attributes.except("id", "idempotency_key", "created_at").merge(
          "inventory_group_id" => @on_request.id, "capacity_pool_id" => nil, "idempotency_key" => "x", "created_at" => Time.current
        ) ])
      end
    end
  end

  test "capacity commands need a confirmed arrangement and Supplier arrangements" do
    draft = assert_raises(AgencyCommand::Error) { IncreaseCapacity.new(**context(@pool), quantity: "1", evidence_note: "x").call }
    assert_equal :invalid_state, draft.code
    confirm!
    refused = assert_raises(AgencyCommand::Error) { IncreaseCapacity.new(**context(@pool), actor: agency_users(:harbor_staff), quantity: "1", evidence_note: "x").call }
    assert_equal :unauthorized, refused.code
  end

  test "the projection matches a full replay" do
    confirm!
    IncreaseCapacity.new(**context(@pool), quantity: "3", evidence_note: "More rooms").call
    RecordSupplierRelease.new(**context(@pool), quantity: "1", evidence_note: "One back").call
    replayed = CapacityTimelineReplay.new(@pool.reload.capacity_events.to_a).call
    assert_equal replayed.quantity, @pool.capacity_projection.current_supplier_capacity
  end

  private

  def group!(**attributes)
    SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, attributes:).call.record
  end

  def confirm!(confirmed_on: "2026-11-09")
    ConfirmSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      confirmed_on:, confirmation_note: "Signed agreement", lock_version: @arrangement.reload.lock_version).call
  end

  def context(group)
    { agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group: }
  end
end
