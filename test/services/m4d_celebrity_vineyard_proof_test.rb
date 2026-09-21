require "test_helper"

class M4DCelebrityVineyardProofTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity O1 provenance survives publish and cabin shortage is unavailable not unpublishable" do
    cruise = m3f_activated_graph!(
      "M4D Celebrity",
      "Celebrity Beyond M4D",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    cruise[:pool] = m3f_add_numeric_pool!(cruise, quantity: 8, label: "O1 cabins M4D")
    m3f_activate!(cruise)
    cruise[:version].reload
    offer = create_from_source(cruise, title: "O1 ocean view", resource: true, pool: true)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: {
        components: [
          occupancy_component("First", "first", "210.00"),
          occupancy_component("Second", "second", "210.00")
        ]
      }
    ).call

    published = PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert published.published?
    binding = published.source_bindings.sole
    assert_equal cruise[:version].id, binding.supplier_arrangement_version_id
    assert_equal cruise[:resource].id, binding.supplier_resource_id
    assert_equal cruise[:pool].id, binding.capacity_pool_id

    RebuildCapacityProjection.new(agency: @agency, pool: cruise[:pool]).call
    projection = CapacityProjection.find_by!(capacity_pool_id: cruise[:pool].id)
    projection.update_columns(current_supplier_capacity: 0)

    live = EvaluateOfferLiveFeasibility.new(
      agency: @agency, version: published, scenario: { persons: 2, resource_units: 1 }
    ).call
    assert_equal "unavailable", live.label
    assert_includes live.reasons.map(&:code), "capacity_shortage"
    assert published.reload.published?
  end

  test "Vineyard one package-only publish with dinner item and illustrative supplement" do
    graph = m3f_activated_graph!(
      "M4D Vineyard",
      "Vineyard weekend M4D",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 8)
    )
    m3f_activate!(graph)
    graph[:version].reload
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { name: "Vineyard weekend published" }
    ).call.record
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: graph[:arrangement].id,
        supplier_arrangement_version_id: graph[:version].id,
        arrangement_item_id: graph[:item].id,
        service_occurrence_id: graph[:occurrence].id,
        client_title: "Coach day",
        placement: "included"
      }
    ).call
    dinner = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Dinner option", fulfillment_basis: "on_request" }
    ).call.record
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: package.reload, offer: dinner,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: dinner.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: package.reload,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "bundled",
        single_occupancy_supplement_rate: "0.5",
        components: [ {
          label: "P", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 90_000, quantity_basis: "persons"
        } ]
      }
    ).call

    result = PublishPackageVersion.new(
      agency: @agency, actor: @actor, package: package.reload,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal :created, result.status
    version = result.record
    assert version.published?
    assert version.owned_service_offer_versions.all?(&:published?)
    assert version.owned_service_offer_versions.any? { |sov|
      sov.definition.client_title == "Dinner option"
    }

    economics = EvaluatePackageIndicativeEconomics.new(
      agency: @agency, actor: @actor, package: package, version: version,
      scenario: { persons: 2 }
    ).call
    assert_includes %i[known unknown incomplete], economics.status
    price = EvaluatePackagePrice.new(package: package, version: version, scenario: { persons: 2 }).call
    assert price.complete
    assert_equal 180_000, price.amount_minor_units
  end

  private

  def occupancy_component(label, key, amount)
    {
      label: label, client_role: "base_price", calculation_kind: "unit_rate",
      amount: amount, quantity_basis: "occupancy_positions", occupancy_position_key: key
    }
  end

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
