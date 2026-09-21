# frozen_string_literal: true

require "test_helper"

class M3e6bAtomicEndingTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Ending Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Ending Departure", status: "draft"
    )
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Ending", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost!
    create_confirmation_trigger!
    activate_arrangement!
  end

  test "end arrangement cancels open commitments and rejects later reopen" do
    open_ids = SupplierCommitment.where(supplier_arrangement: @arrangement).select(&:open_state?).map(&:id)
    selected = open_ids.map { |id| "cancel_open_commitment:#{id}" }
    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call

    assert preview.record.payload.fetch("blockers").empty?, preview.record.payload.fetch("blockers").inspect

    key = SecureRandom.uuid
    result = EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      preview_token: preview.raw_token,
      idempotency_key: key,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call

    assert_equal :created, result.status
    assert @arrangement.reload.ended?
    assert_equal 0, SupplierCommitment.where(supplier_arrangement: @arrangement).count(&:open_state?)
    assert AuditEvent.exists?(action: "supplier_arrangement.ended")

    replay = EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      preview_token: preview.raw_token,
      idempotency_key: key,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call
    assert_equal :replayed, replay.status
    assert_equal result.record.id, replay.record.id

    commitment = SupplierCommitment.where(supplier_arrangement: @arrangement).first!
    disposition = commitment.current_disposition
    error = assert_raises(AgencyCommand::Error) do
      ReopenSupplierCommitment.new(
        agency: @agency, actor: @actor, commitment:, disposition:,
        reason: "Mistake", idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_match(/ended/i, error.message)
  end

  test "ending withdraws remaining Pool capacity using existing definition evidence" do
    graph = build_activated_established_capacity_graph(
      contractor: @supplier, provider: @supplier, prefix: "Ending Pool", quantity: 5
    )
    arrangement = graph[:arrangement]
    selected = [ "withdraw_future_capacity:#{graph[:pool].id}" ]
    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement:,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call
    assert preview.record.payload.fetch("blockers").empty?, preview.record.payload.fetch("blockers").inspect

    EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement:,
      preview_token: preview.raw_token,
      idempotency_key: SecureRandom.uuid,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call

    assert arrangement.reload.ended?
    assert_equal 0, graph[:projection].reload.current_supplier_capacity
    assert graph[:pool].capacity_events.exists?(event_type: "withdrawn")
  end

  test "same-key replay succeeds after preview expiry" do
    open_ids = SupplierCommitment.where(supplier_arrangement: @arrangement).select(&:open_state?).map(&:id)
    selected = open_ids.map { |id| "cancel_open_commitment:#{id}" }
    preview = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      selected_cascade_keys: selected,
      ending_reason: "planning_concluded"
    ).call
    key = SecureRandom.uuid
    first = EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      preview_token: preview.raw_token, idempotency_key: key,
      selected_cascade_keys: selected, ending_reason: "planning_concluded"
    ).call
    preview.record.update_columns(expires_at: 1.minute.ago, updated_at: Time.current)

    second = EndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      preview_token: preview.raw_token, idempotency_key: key,
      selected_cascade_keys: selected, ending_reason: "planning_concluded"
    ).call
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
  end

  private

  def create_ready_cost!
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Ending cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:ending6b",
      readiness_provenance: "Signed"
    )
  end

  def create_confirmation_trigger!
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def activate_arrangement!
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Approved",
        confirmed_without_identifier_reason: "Later"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
  end
end
