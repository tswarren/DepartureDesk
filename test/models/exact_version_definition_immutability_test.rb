require "test_helper"

class ExactVersionDefinitionImmutabilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Immutability Supplier")
    @departure = create_capacity_departure(@agency, name: "Immutability Departure")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Immutability", capacity_management: "managed"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    build_full_definition_graph!
    @original_amount = 25_000
    activate!
  end

  test "activated definition families reject model and SQL mutation" do
    assert_definition_families_frozen!(@version)
  end

  test "superseded predecessor definition families reject mutation" do
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: successor,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: successor.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: evidence_attributes,
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call

    assert_equal "superseded", @version.reload.status
    assert_definition_families_frozen!(@version)
  end

  test "abandoned retained version definition families reject mutation" do
    abandoned_graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Abandoned", capacity_management: "unmanaged"
    )
    abandoned_version = abandoned_graph[:version]
    AbandonSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: abandoned_graph[:arrangement],
      reason: "Not pursuing",
      arrangement_lock_version: abandoned_graph[:arrangement].lock_version,
      version_lock_version: abandoned_version.lock_version
    ).call

    assert_equal "abandoned", abandoned_version.reload.status
    definition = abandoned_version.arrangement_item_definitions.sole
    assert_frozen_definition!(definition, :name, "Mutated abandoned item")
  end

  test "insert against activated version is rejected" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      ArrangementItemDefinition.transaction(requires_new: true) do
        ArrangementItemDefinition.insert!({
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_arrangement_version_id: @version.id,
          arrangement_item_id: @graph[:item].id,
          name: "Smuggled",
          category: "lodging",
          position: 99,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
  end

  test "successor draft remains editable and independent" do
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    draft_item = successor.arrangement_item_definitions.sole
    draft_item.update!(name: "Successor revised item")
    assert_equal "Successor revised item", draft_item.reload.name
    assert_equal "Immutability item", @version.arrangement_item_definitions.sole.reload.name
  end

  test "activated cost rewrite is rejected and reservation commitment keeps original rate" do
    component = @version.supplier_cost_components.where(calculation_kind: "fixed").sole
    assert_equal @original_amount, component.amount_minor_units

    assert_raises(ActiveRecord::RecordInvalid) do
      component.update!(amount_minor_units: 40_000)
    end
    assert_equal @original_amount, component.reload.amount_minor_units

    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostComponent.transaction(requires_new: true) do
        SupplierCostComponent.connection.execute(<<~SQL.squish)
          UPDATE supplier_cost_components
          SET amount_minor_units = 40000
          WHERE id = '#{component.id}'
        SQL
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
    assert_equal @original_amount, component.reload.amount_minor_units

    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
    scope = reservation.revisions.where(status: "requested").sole.scopes.sole
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: {
        scope_ids: [ scope.id ],
        channel: "portal",
        reference_note: "Confirmed",
        outcomes: { scope.id => { outcome_kind: "confirmed" } },
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Confirmed",
          confirmed_without_identifier_reason: "Later"
        }
      },
      idempotency_key: SecureRandom.uuid
    ).call

    commitment = SupplierCommitment.find_by!(
      supplier_commitment_trigger_definition_id: @reservation_trigger.id
    )
    assert_equal @original_amount, commitment.amount_minor_units
  end

  test "legal lifecycle transitions succeed and illegal ones fail" do
    other = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Lifecycle", capacity_management: "unmanaged"
    )
    draft = other[:version]
    assert draft.update!(status: "activated", activated_at: Time.current)

    activated = draft
    assert_raises(ActiveRecord::RecordInvalid) do
      activated.update!(status: "draft", activated_at: nil)
    end
    activated.reload
    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangementVersion.transaction(requires_new: true) do
        SupplierArrangementVersion.connection.execute(<<~SQL.squish)
          UPDATE supplier_arrangement_versions
          SET status = 'draft', activated_at = NULL
          WHERE id = '#{activated.id}'
        SQL
      end
    end
    assert_match(/lifecycle/i, error.message)

    assert activated.update!(status: "superseded", superseded_at: Time.current)

    abandonable = other[:arrangement].versions.create!(
      agency: @agency, departure: @departure, version_number: 2, status: "draft"
    )
    assert abandonable.update!(
      status: "abandoned", abandoned_at: Time.current, abandoned_reason: "Stopped"
    )
  end

  private

  def build_full_definition_graph!
    @pair = classify_capacity_graph_pair(@graph)
    @pool = CapacityPool.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      supplying_supplier: @supplier,
      inventory_mode: "block", measurement_basis: "resource_units",
      effective_time_zone: @graph[:occurrence_definition].time_zone
    )
    CapacityPoolDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      capacity_pair_definition: @pair, capacity_pool: @pool,
      label: "Block", normalized_label: "block", unit_label: "rooms",
      proposed_opening_quantity: 8, evidence_kind: "contract",
      evidence_on: Date.current, evidence_reference_note: "Signed", position: 1
    )

    owner = {
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version
    }
    category = SupplierCostParticipantCategory.create!(
      owner.merge(arrangement_item: @graph[:item], label: "Adult", position: 1)
    )
    assumption = SupplierCostUsageAssumption.create!(
      owner.merge(arrangement_item: @graph[:item], expected_resource_units: 8)
    )
    profile = SupplierCostOccupancyProfile.create!(
      owner.merge(
        arrangement_item: @graph[:item],
        supplier_cost_usage_assumption: assumption,
        label: "Double", resource_unit_count: 8, position: 1
      )
    )
    SupplierCostOccupancyProfilePosition.create!(
      owner.merge(
        arrangement_item: @graph[:item],
        supplier_cost_usage_assumption: assumption,
        supplier_cost_occupancy_profile: profile,
        participant_category: category,
        occupancy_position: 1
      )
    )
    source = SupplierCostSource.create!(
      owner.merge(
        arrangement_item: @graph[:item], charging_supplier: @supplier,
        label: "Room cost", position: 1
      )
    )
    definition = SupplierCostDefinition.create!(
      owner.merge(
        supplier_cost_source: source, stage: "contracted", status: "working",
        mode: "calculated", currency: "USD", rounding_mode: "half_up"
      )
    )
    fixed = SupplierCostComponent.create!(
      owner.merge(
        supplier_cost_definition: definition, label: "Nightly",
        economic_role: "supplier_charge", calculation_kind: "fixed",
        amount_minor_units: 25_000, position: 1
      )
    )
    percentage = SupplierCostComponent.create!(
      owner.merge(
        supplier_cost_definition: definition, label: "Tax",
        economic_role: "supplier_charge", calculation_kind: "percentage",
        rate: BigDecimal("0.1"), percentage_treatment: "additive", position: 2
      )
    )
    SupplierCostComponentBase.create!(
      owner.merge(
        supplier_cost_definition: definition,
        supplier_cost_component: percentage,
        base_component: fixed, direction: "add", position: 1
      )
    )
    definition.update!(
      status: "forecast_ready", forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition),
      readiness_provenance: "Signed terms"
    )
    @component = fixed
    @reservation_trigger = SupplierCommitmentTriggerDefinition.create!(
      owner.merge(
        committed_supplier: @supplier,
        trigger_kind: "reservation_confirmation",
        authority_shape: "fixed_contracted_amount",
        description: "Contracted room amount",
        currency: "USD",
        supplier_cost_source: source,
        supplier_cost_definition: definition,
        supplier_cost_component: fixed,
        position: 1
      )
    )
  end

  def activate!
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: evidence_attributes,
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call
    assert_equal "activated", @version.reload.status
  end

  def evidence_attributes
    {
      evidence_kind: "supplier_confirmation", evidence_on: Date.current,
      channel: "portal", reference_note: "Supplier approved exact terms",
      confirmed_without_identifier_reason: "Supplier did not issue one"
    }
  end

  def assert_definition_families_frozen!(version)
    representatives = [
      [ version.arrangement_item_definitions.sole, :name, "Mutated item" ],
      [ version.service_occurrence_definitions.sole, :name, "Mutated occurrence" ],
      [ version.supplier_resource_definitions.sole, :name, "Mutated resource" ],
      [ version.capacity_pair_definitions.sole, :classification, "not_applicable" ],
      [ version.capacity_pool_definitions.sole, :label, "Mutated pool" ],
      [ version.supplier_cost_sources.sole, :label, "Mutated source" ],
      [ version.supplier_cost_definitions.sole, :readiness_provenance, "Mutated provenance" ],
      [ version.supplier_cost_components.where(calculation_kind: "fixed").sole, :amount_minor_units, 40_000 ],
      [ version.supplier_cost_components.find_by!(calculation_kind: "percentage")
          .supplier_cost_component_bases.sole, :position, 9 ],
      [ version.supplier_cost_participant_categories.sole, :label, "Mutated category" ],
      [ version.supplier_cost_usage_assumptions.sole, :expected_resource_units, 99 ],
      [ version.supplier_cost_occupancy_profiles.sole, :label, "Mutated profile" ],
      [ SupplierCostOccupancyProfilePosition.where(supplier_arrangement_version_id: version.id).sole,
        :occupancy_position, 9 ],
      [ version.supplier_commitment_trigger_definitions.sole, :description, "Mutated trigger" ]
    ]
    representatives.each do |record, attribute, value|
      assert_frozen_definition!(record, attribute, value)
    end
  end

  def assert_frozen_definition!(record, attribute, new_value)
    original = record.public_send(attribute)
    quoted_value = record.class.connection.quote(new_value)

    assert_raises(ActiveRecord::RecordInvalid, ActiveRecord::ReadonlyAttributeError) do
      record.update!(attribute => new_value)
    end
    assert_equal original, record.reload.public_send(attribute)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      record.class.transaction(requires_new: true) do
        record.class.connection.execute(<<~SQL.squish)
          UPDATE #{record.class.table_name}
          SET #{attribute} = #{quoted_value}
          WHERE id = '#{record.id}'
        SQL
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
    assert_equal original, record.reload.public_send(attribute)

    assert_not record.destroy
    assert record.class.exists?(record.id)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      record.class.transaction(requires_new: true) do
        record.class.connection.execute(<<~SQL.squish)
          DELETE FROM #{record.class.table_name} WHERE id = '#{record.id}'
        SQL
      end
    end
    assert_match(/immutable after leaving draft/i, error.message)
    assert record.class.exists?(record.id)
  end
end
