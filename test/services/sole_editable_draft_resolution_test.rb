require "test_helper"

class SoleEditableDraftResolutionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "Successor remediation")
    @departure.update!(
      status: "active", departure_reference: "D-930001", first_activated_at: 3.days.ago
    )
    @contractor = create_capacity_supplier(@agency, "Successor Contractor")
    @provider = create_capacity_supplier(@agency, "Successor Provider")
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure, contracting_supplier: @contractor,
      name: "Versioned Arrangement"
    )
    @item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @occurrence = @item.service_occurrences.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      status: "planned"
    )
    @resource = @item.supplier_resources.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement
    )

    activated_at = 2.days.ago
    @superseded = create_version(1, "superseded", activated_at:, superseded_at: 1.day.ago)
    @activated = create_version(2, "activated", activated_at: 1.day.ago)
    @draft = create_version(3, "draft")
    @arrangement.update!(status: "active", governing_version: @activated)
  end

  test "structure capacity and cost mutations target the sole editable draft" do
    draft_definition = item_definition(@draft)
    updated = UpdateArrangementItem.new(
      agency: @agency, actor: @actor, definition: draft_definition,
      attributes: {
        name: "Edited successor item", category: "lodging",
        default_service_provider_id: @provider.id
      },
      lock_version: draft_definition.lock_version
    ).call

    assert_equal @draft.id, updated.record.supplier_arrangement_version_id
    assert_equal "Edited successor item", updated.record.name
    assert_equal "Version 2 item", item_definition(@activated).name

    pair = ClassifyCapacityPair.new(
      agency: @agency, actor: @actor, item: @item,
      service_occurrence: @occurrence, supplier_resource: @resource,
      classification: "not_applicable", version_lock_version: @draft.reload.lock_version
    ).call.record
    assert_equal @draft.id, pair.supplier_arrangement_version_id

    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      attributes: {
        label: "Successor cost", charging_supplier_id: @contractor.id,
        arrangement_item_id: @item.id
      },
      version_lock_version: @draft.reload.lock_version,
      idempotency_key: "successor-cost-source"
    ).call.record
    assert_equal @draft.id, source.supplier_arrangement_version_id
  end

  test "forecast selects the sole editable draft" do
    source = @draft.supplier_cost_sources.create!(
      owner_attributes.merge(
        charging_supplier: @contractor, arrangement_item: @item,
        label: "Successor forecast", position: 1
      )
    )
    definition = source.supplier_cost_definitions.create!(
      owner_attributes.merge(
        stage: "estimate", mode: "zero_cost", currency: "USD",
        rounding_mode: "half_up", zero_cost_reason: "Included",
        status: "working"
      )
    )
    definition.update!(
      status: "forecast_ready", forecast_ready_by: @actor,
      forecast_ready_at: Time.current,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition)
    )

    result = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement
    ).call.arrangements.sole

    assert_equal @draft.id, result.version_id
    assert_equal source.id, result.sources.sole.source_id
    assert result.complete
  end

  test "activated and superseded definitions cannot be mutated" do
    [ @activated, @superseded ].each do |historical_version|
      definition = item_definition(historical_version)
      assert_raises(ActiveRecord::RecordNotFound) do
        UpdateArrangementItem.new(
          agency: @agency, actor: @actor, definition: definition,
          attributes: {
            name: "Forbidden historical edit", category: "lodging",
            default_service_provider_id: @provider.id
          },
          lock_version: definition.lock_version
        ).call
      end
      assert_match(/Version [12] item/, definition.reload.name)
    end
  end

  private

  def create_version(number, status, activated_at: nil, superseded_at: nil)
    version = @arrangement.versions.create!(
      agency: @agency, departure: @departure, version_number: number, status: "draft"
    )
    version.arrangement_item_definitions.create!(
      owner_attributes(version).merge(
        arrangement_item: @item, name: "Version #{number} item",
        category: "lodging", capacity_management: "managed",
        default_service_provider: @provider, position: 1
      )
    )
    version.service_occurrence_definitions.create!(
      owner_attributes(version).merge(
        arrangement_item: @item, service_occurrence: @occurrence,
        name: "Version #{number} occurrence", starts_on: @departure.starts_on,
        ends_on: @departure.starts_on, time_zone: "UTC",
        service_provider: @provider
      )
    )
    version.supplier_resource_definitions.create!(
      owner_attributes(version).merge(
        arrangement_item: @item, supplier_resource: @resource,
        name: "Version #{number} resource", position: 1
      )
    )
    case status
    when "draft"
      version
    when "activated"
      version.update!(status: "activated", activated_at: activated_at || Time.current)
    when "superseded"
      version.update!(status: "activated", activated_at: activated_at || 2.days.ago)
      version.update!(status: "superseded", superseded_at: superseded_at || 1.day.ago)
    when "abandoned"
      version.update!(
        status: "abandoned",
        abandoned_at: Time.current,
        abandoned_reason: "Test abandoned version"
      )
    else
      raise ArgumentError, "unsupported status #{status}"
    end
    version
  end

  def owner_attributes(version = @draft)
    {
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: version
    }
  end

  def item_definition(version)
    version.arrangement_item_definitions.find_by!(arrangement_item: @item)
  end
end
