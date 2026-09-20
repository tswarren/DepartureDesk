require "test_helper"

class EvaluateServiceOfferSourceCompatibilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Compat Contractor")
    @provider = create_capacity_supplier(@agency, "Compat Provider")
    @departure = create_capacity_departure(@agency, name: "Compat Departure")
    @graph = build_activated_unestablished_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @provider,
      actor: @actor, prefix: "Compat"
    )
  end

  test "equivalent bound facts on the same activated version" do
    offer = create_offer_from(@graph)
    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "equivalent", outcome.result
    assert outcome.annotations["cost_graph_not_compared"]
  end

  test "material provider change on an activated successor" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    other = create_capacity_supplier(@agency, "New Provider")
    successor.service_occurrence_definitions.find_by!(service_occurrence_id: @graph[:occurrence].id)
      .update!(service_provider: other)
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "material", outcome.result
    assert_includes outcome.binding_outcomes.first.reasons, "Effective provider changed."
  end

  test "material occurrence dates on an activated successor" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    successor.service_occurrence_definitions.find_by!(service_occurrence_id: @graph[:occurrence].id)
      .update!(starts_on: Date.new(2026, 6, 2), ends_on: Date.new(2026, 6, 2))
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "material", outcome.result
    assert_includes outcome.binding_outcomes.first.reasons, "Promised Occurrence dates, times, zone, or provider changed."
  end

  test "material pair classification on an activated successor" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    successor.capacity_pair_definitions.sole.update!(classification: "not_applicable")
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "material", outcome.result
    assert_includes outcome.binding_outcomes.first.reasons, "Bound pair classification changed."
  end

  test "unknown missing lineage" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "UPDATE arrangement_item_definitions SET copied_from_id = NULL WHERE id = ?",
        successor.arrangement_item_definitions.find_by!(arrangement_item_id: @graph[:item].id).id
      ])
    )
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "unknown", outcome.result
  end

  test "draft successor is ignored" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    other = create_capacity_supplier(@agency, "Draft Only")
    successor.arrangement_item_definitions.first.update!(default_service_provider: other)
    successor.service_occurrence_definitions.first.update!(service_provider: other)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "equivalent", outcome.result
  end

  test "unrelated item is ignored" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    extra_item = successor.supplier_arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    successor.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: successor.supplier_arrangement,
      arrangement_item: extra_item, name: "Unrelated", category: "dining", position: 2,
      capacity_management: "unmanaged"
    )
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "equivalent", outcome.result
  end

  test "cost-only change is not an evaluator result" do
    offer = create_offer_from(@graph)
    successor = create_successor_draft
    successor.supplier_cost_sources.create!(
      agency: @agency, departure: @departure, supplier_arrangement: successor.supplier_arrangement,
      arrangement_item: @graph[:item], charging_supplier: @contractor, label: "Later cost",
      position: 99
    )
    promote_successor!(successor)

    outcome = EvaluateServiceOfferSourceCompatibility.new(
      agency: @agency, actor: @actor, offer: offer
    ).call
    assert_equal "equivalent", outcome.result
    assert outcome.annotations["cost_graph_not_compared"]
  end

  private

  def create_offer_from(graph)
    CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: graph[:arrangement].id,
        supplier_arrangement_version_id: graph[:version].id,
        arrangement_item_id: graph[:item].id,
        service_occurrence_id: graph[:occurrence].id,
        supplier_resource_id: graph[:resource].id,
        capacity_pool_id: graph[:pool]&.id,
        client_title: "Bound service"
      }
    ).call.record
  end

  def create_successor_draft
    CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @graph[:arrangement],
      arrangement_lock_version: @graph[:arrangement].reload.lock_version,
      version_lock_version: @graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def promote_successor!(draft)
    now = Time.current
    @graph[:version].reload.update!(status: "superseded", superseded_at: now)
    draft.update!(status: "activated", activated_at: now)
    @graph[:arrangement].reload.update!(governing_version: draft)
  end
end
