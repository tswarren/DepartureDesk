require "test_helper"

class OfferPathConsequencesDisclosureTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "arrangement ending evaluation discloses published offer paths without blockers" do
    graph = m3f_activated_graph!(
      "M4D Ending paths",
      "Ending disclosure departure",
      starts_on: Date.new(2027, 9, 1),
      ends_on: Date.new(2027, 9, 8)
    )
    m3f_activate!(graph)
    graph[:version].reload
    offer = create_from_source(graph, title: "Published cabin", resource: true)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "per_person", amount: "100.00" }
    ).call
    PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    evaluation = EvaluateSupplierArrangementEnding.new(
      agency: @agency, arrangement: graph[:arrangement]
    ).call
    assert evaluation.offer_path_consequences.any? { |row|
      row.offer_type == "ServiceOffer" && row.offer_id == offer.id
    }
    assert evaluation.blockers.none? { |blocker| blocker.code.to_s.include?("offer") }
  end

  test "supplier inactivation inventory lists published offer path consequences" do
    graph = m3f_activated_graph!(
      "M4D Supplier paths",
      "Supplier disclosure departure",
      starts_on: Date.new(2027, 10, 1),
      ends_on: Date.new(2027, 10, 8)
    )
    graph[:pool] = m3f_add_numeric_pool!(graph, quantity: 4, label: "Coach seats M4D")
    m3f_activate!(graph)
    graph[:version].reload
    offer = create_from_source(graph, title: "Published coach", occurrence: true, resource: true, pool: true)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "per_person", amount: "40.00" }
    ).call
    PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    rows = ListPublishedOfferPathConsequences.new(
      agency: @agency, supplier: graph[:supplier]
    ).call
    assert rows.any? { |row| row.offer_id == offer.id }
  end

  private

  def create_from_source(graph, title:, occurrence: true, resource: false, pool: false)
    attrs = {
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      client_title: title
    }
    attrs[:service_occurrence_id] = graph[:occurrence].id if occurrence
    attrs[:supplier_resource_id] = graph[:resource].id if resource
    attrs[:capacity_pool_id] = graph[:pool]&.id if pool
    CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: graph[:departure],
      idempotency_key: SecureRandom.uuid, attributes: attrs
    ).call.record
  end
end
