require "test_helper"

class M4CCelebrityVineyardProofTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity package includes cruise shape without invented fares" do
    cruise = m3f_activated_graph!(
      "M4C Celebrity",
      "Celebrity Beyond M4C",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: cruise[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { name: "Celebrity cruise package" }
    ).call.record
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: cruise[:arrangement].id,
        supplier_arrangement_version_id: cruise[:version].id,
        arrangement_item_id: cruise[:item].id,
        service_occurrence_id: cruise[:occurrence].id,
        supplier_resource_id: cruise[:resource].id,
        client_title: "O1 cruise"
      }
    ).call
    inclusion = package.reload.editable_draft_version.inclusions.sole
    amounts = inclusion.service_offer_version.price_definition&.service_offer_price_components&.map(&:amount_minor_units) || []
    assert_not_includes amounts, 162_400
    assert inclusion.inline_create?
  end

  test "Vineyard unscoped P with optional s is 2P not 4P and draft adopt works" do
    graph = m3f_activated_graph!(
      "M4C Vineyard",
      "Vineyard weekend M4C",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 8)
    )
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { name: "Vineyard weekend" }
    ).call.record
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "bundled",
        single_occupancy_supplement_rate: "1.0",
        components: [ {
          label: "P", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 80_000, quantity_basis: "persons"
        } ]
      }
    ).call
    two = EvaluatePackagePrice.new(package: package.reload, scenario: { persons: 2 }).call
    assert_equal 160_000, two.amount_minor_units
    one = EvaluatePackagePrice.new(package: package, scenario: { persons: 1 }).call
    assert_equal 160_000, one.amount_minor_units

    dinner = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Dinner", fulfillment_basis: "on_request" }
    ).call.record
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: package, offer: dinner,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: dinner.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal package.reload.editable_draft_version.id, dinner.reload.editable_draft_version.owning_package_version_id

    abandoned = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Abandoned dinner", fulfillment_basis: "on_request" }
    ).call.record
    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: abandoned, reason: "Stopped",
      offer_lock_version: abandoned.lock_version,
      version_lock_version: abandoned.editable_draft_version.lock_version
    ).call
    error = assert_raises(AgencyCommand::Error) do
      AdoptServiceOfferDraftAsPackageOnly.new(
        agency: @agency, actor: @actor, package: package.reload, offer: abandoned,
        version_lock_version: package.editable_draft_version.lock_version,
        offer_version_lock_version: abandoned.versions.find_by(status: "abandoned").lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "one package economics figure uses package revenue not service prices" do
    graph = m3f_activated_graph!(
      "M4C Vineyard econ",
      "Vineyard economics M4C",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 8)
    )
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { name: "Vineyard weekend economics" }
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
        supplier_resource_id: graph[:resource].id,
        client_title: "Coach"
      }
    ).call
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: package.reload,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "bundled",
        components: [ {
          label: "P", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 80_000, quantity_basis: "persons"
        } ]
      }
    ).call
    economics = EvaluatePackageIndicativeEconomics.new(
      agency: @agency, actor: @actor, package: package.reload, scenario: { persons: 2 }
    ).call
    assert_equal :known, economics.status
    assert_equal 160_000, economics.client_revenue_minor_units
    assert_equal 0, economics.forecast_supplier_cost_minor_units
    assert_equal 160_000, economics.indicative_margin_minor_units
  end
end
