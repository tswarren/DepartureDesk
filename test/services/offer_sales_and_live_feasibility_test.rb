require "test_helper"

class OfferSalesAndLiveFeasibilityTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M4D Live Feasibility", status: "draft")
    ActivateDeparture.new(
      agency: @agency, actor: @actor, departure: @departure,
      lock_version: @departure.lock_version
    ).call
    @departure.reload
  end

  test "pause resume and retire package sales" do
    package = publish_bundled_package!("Weekend sales")
    version = package.current_published_version
    assert version.sales_state.sales_enabled

    PausePackageSales.new(agency: @agency, actor: @actor, package: package).call
    assert_not version.reload.sales_state.sales_enabled
    live = EvaluateOfferLiveFeasibility.new(
      agency: @agency, version: version.owned_service_offer_versions.first, package_version: version,
      scenario: { persons: 2 }
    ).call
    assert_equal "unavailable", live.label

    ResumePackageSales.new(agency: @agency, actor: @actor, package: package).call
    assert version.reload.sales_state.sales_enabled

    RetirePackageVersion.new(agency: @agency, actor: @actor, package: package, reason: "Done").call
    assert_equal "retired", version.reload.status
    assert_nil package.reload.current_published_version_id
  end

  test "pause resume and retire standalone service offer sales" do
    offer = publish_standalone_offer!("Coach transfer")
    version = offer.current_published_version
    PauseServiceOfferSales.new(agency: @agency, actor: @actor, offer: offer).call
    assert_not version.reload.sales_state.sales_enabled
    ResumeServiceOfferSales.new(agency: @agency, actor: @actor, offer: offer).call
    assert version.reload.sales_state.sales_enabled
    RetireServiceOfferVersion.new(agency: @agency, actor: @actor, offer: offer, reason: "Done").call
    assert_equal "retired", version.reload.status
  end

  test "on-request fulfillment is on_request without inventing capacity counts" do
    offer = publish_standalone_offer!("On request dinner", fulfillment: "on_request")
    version = offer.current_published_version
    live = EvaluateOfferLiveFeasibility.new(
      agency: @agency, version: version, scenario: { persons: 2 }
    ).call
    assert_equal "on_request", live.label
    assert live.reasons.any? { |row| row.code == "fulfillment" }
  end

  test "sales cap stacks as unavailable when scenario exceeds persons cap" do
    package = publish_bundled_package!("Capped weekend")
    version = package.current_published_version
    version.update!(sales_cap_quantity: 1, sales_cap_basis: "persons")
    live = EvaluateOfferLiveFeasibility.new(
      agency: @agency,
      version: version.owned_service_offer_versions.first,
      package_version: version,
      scenario: { persons: 2 }
    ).call
    assert_equal "unavailable", live.label
    assert live.reasons.any? { |row| row.code == "cap" }
  end

  test "missing required sales-cap quantity is unavailable" do
    package = publish_bundled_package!("Cap needs quantity")
    version = package.current_published_version
    version.update!(sales_cap_quantity: 2, sales_cap_basis: "resource_units")
    live = EvaluateOfferLiveFeasibility.new(
      agency: @agency,
      version: version.owned_service_offer_versions.first,
      package_version: version,
      scenario: { persons: 2, resource_units: nil }
    ).call
    assert_equal "unavailable", live.label
    assert live.reasons.any? { |row| row.message.match?(/quantity required/i) }
  end

  private

  def publish_standalone_offer!(title, fulfillment: "agency_fulfilled")
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: title, fulfillment_basis: fulfillment }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "fixed_per_service", amount: "50.00" }
    ).call
    PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    offer.reload
  end

  def publish_bundled_package!(name)
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: name }
    ).call.record
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Dinner", fulfillment_basis: "on_request", placement: "included" }
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
    PublishPackageVersion.new(
      agency: @agency, actor: @actor, package: package.reload,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    package.reload
  end
end
