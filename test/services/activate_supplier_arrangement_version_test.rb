require "test_helper"

class ActivateSupplierArrangementVersionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @supplier = create_capacity_supplier(@agency, "Activation Supplier")
    @departure = create_capacity_departure(
      @agency, name: "First Activation", status: "draft"
    )
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Activation", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost(stage: "contracted")
    create_trigger
  end

  test "first activation atomically records evidence manifest selections commitment and one audit" do
    key = SecureRandom.uuid
    arrangement_lock = @arrangement.lock_version
    version_lock = @version.lock_version
    result = activate(
      idempotency_key: key,
      arrangement_lock_version: arrangement_lock,
      version_lock_version: version_lock
    )
    activation = result.record

    assert_equal :created, result.status
    assert_equal "active", @arrangement.reload.status
    assert_equal @version.id, @arrangement.governing_version_id
    assert_equal "activated", @version.reload.status
    assert_equal 1, activation.cost_selections.count
    assert_equal 1, activation.supplier_commitments.count
    assert activation.cost_source_coverage_acknowledged?
    assert activation.commitment_trigger_coverage_acknowledged?
    assert_equal 1, SupplierConfirmationActivationLink.where(
      supplier_arrangement_activation: activation
    ).count
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.activated", subject_id: @arrangement.id
    ).count

    assert_no_changes -> { SupplierArrangementActivation.count } do
      assert_no_changes -> { SupplierCommitment.count } do
        assert_no_changes -> { SupplierConfirmationActivationLink.count } do
          replay = activate(
            idempotency_key: key,
            arrangement_lock_version: arrangement_lock,
            version_lock_version: version_lock
          )
          assert_equal :replayed, replay.status
          assert_equal activation.id, replay.record.id
        end
      end
    end
  end

  test "new evidence creates and links a qualified Supplier identifier" do
    activation = activate(
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Supplier approved exact terms"
      },
      identifier_attributes: {
        identifier_type: "confirmation_number",
        issuer_context: "contracting_supplier",
        display_value: " CN-4401 "
      }
    ).record
    identifier = activation.supplier_confirmation.supplier_issued_identifiers.sole
    assert_equal "CN-4401", identifier.display_value
    assert_equal "cn-4401", identifier.normalized_value
  end

  test "numeric Pool receives one establishment event projection and confirmation link" do
    add_numeric_pool
    activation = activate.record
    entry = activation.capacity_entries.sole
    event = entry.establishment_event

    assert_equal "established", entry.entry_kind
    assert_equal 8, event.quantity
    assert_equal 8, event.capacity_pool.capacity_projection.current_supplier_capacity
    assert SupplierConfirmationCapacityEventLink.exists?(
      supplier_confirmation: activation.supplier_confirmation,
      capacity_event: event
    )
  end

  test "all coverage attestations and provisional estimate acknowledgment are required" do
    replace_ready_cost_with_estimate
    {
      cost_source_coverage_acknowledged: false,
      commitment_trigger_coverage_acknowledged: false,
      provisional_costs_acknowledged: false
    }.each do |field, value|
      assert_no_difference -> { SupplierArrangementActivation.count } do
        error = assert_raises(AgencyCommand::Error) do
          activate(**{ field => value }, idempotency_key: SecureRandom.uuid)
        end
        assert_equal :invalid, error.code
      end
    end
  end

  test "a failure after evidence creation rolls back every activation consequence" do
    @version.supplier_commitment_trigger_definitions.first.update!(
      authority_shape: "confirmed_quantity", fixed_quantity: nil
    )
    add_numeric_pool

    assert_no_difference -> { SupplierConfirmation.count } do
      assert_no_difference -> { SupplierArrangementActivation.count } do
        assert_no_difference -> { CapacityEvent.count } do
          error = assert_raises(AgencyCommand::Error) { activate }
          assert_equal :invalid, error.code
        end
      end
    end
    assert_equal "draft", @arrangement.reload.status
    assert_equal "draft", @version.reload.status
  end

  test "compatible existing evidence is reused and incompatible evidence is rejected" do
    confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      confirming_supplier: @supplier,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.current, channel: "portal",
      reference_note: "Existing confirmation",
      confirmed_without_identifier_reason: "Supplier did not issue one",
      actor: @actor, recorded_at: Time.current
    )
    activation = activate(
      existing_confirmation_id: confirmation.id,
      evidence_attributes: {}
    ).record
    assert_equal confirmation.id, activation.supplier_confirmation_id

    other_graph = build_second_graph
    error = assert_raises(AgencyCommand::Error) do
      activate_graph(
        other_graph,
        existing_confirmation_id: confirmation.id,
        evidence_attributes: {}
      )
    end
    assert_equal :invalid, error.code
  end

  test "first activation permanently blocks return to draft" do
    activate
    error = assert_raises(AgencyCommand::Error) do
      ReturnDepartureToDraft.new(
        agency: @agency, actor: @actor, departure: @departure.reload,
        reason: "Rework", lock_version: @departure.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_equal "active", @departure.reload.status
  end

  test "ordinary Supplier inactivation blocks on committed Supplier snapshot and force preserves it" do
    commitment = activate.record.supplier_commitments.sole
    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency, actor: @admin, supplier: @supplier.reload,
        status: "inactive", lock_version: @supplier.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code

    ChangeSupplierStatus.new(
      agency: @agency, actor: @admin, supplier: @supplier.reload,
      status: "inactive", lock_version: @supplier.lock_version,
      force: true, force_reason: "Supplier ceased trading"
    ).call
    assert SupplierCommitment.exists?(commitment.id)
    audit = AuditEvent.where(
      action: "supplier.inactivated", subject_id: @supplier.id
    ).last
    assert_includes audit.details["preserved_supplier_commitment_ids"], commitment.id
  end

  private

  def activate(**overrides)
    attributes = {
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version, arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    }.merge(overrides)
    ActivateSupplierArrangementVersion.new(**attributes).call
  end

  def create_ready_cost(stage:)
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Entered lodging cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: stage, status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included in package", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:test",
      readiness_provenance: (stage == "contracted" ? "Signed terms" : nil)
    )
  end

  def replace_ready_cost_with_estimate
    SupplierCostDefinition.delete_all
    SupplierCostSource.delete_all
    create_ready_cost(stage: "estimate")
  end

  def create_trigger(version: @version, arrangement: @arrangement, departure: @departure)
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Ten guaranteed rooms",
      fixed_quantity: 10, quantity_basis: "resource_units", position: 1
    )
  end

  def add_numeric_pool
    @graph[:item_definition].update!(capacity_management: "managed")
    pair = classify_capacity_graph_pair(@graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      supplying_supplier: @supplier,
      inventory_mode: "block", measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    )
    CapacityPoolDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      capacity_pair_definition: pair, capacity_pool: pool,
      label: "Eight rooms", normalized_label: "eight rooms",
      unit_label: "rooms", proposed_opening_quantity: 8,
      evidence_kind: "contract", evidence_on: Date.current,
      evidence_reference_note: "Signed room block", position: 1
    )
  end

  def build_second_graph
    graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Other", capacity_management: "unmanaged"
    )
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item], charging_supplier: @supplier,
      label: "Other cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_source: source, stage: "contracted",
      status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:other", readiness_provenance: "Signed"
    )
    create_trigger(
      version: graph[:version], arrangement: graph[:arrangement], departure: @departure
    )
    graph
  end

  def activate_graph(graph, **overrides)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor,
      arrangement: graph[:arrangement], version: graph[:version],
      arrangement_lock_version: graph[:arrangement].lock_version,
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      **overrides
    ).call
  end
end
