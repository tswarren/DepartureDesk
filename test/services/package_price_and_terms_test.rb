require "test_helper"

class PackagePriceAndTermsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Price Package Departure")
    @package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Weekend" }
    ).call.record
  end

  test "bundled one-person P times two is 2P not 4P and optional s is absent" do
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: @package,
      version_lock_version: @package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "bundled",
        components: [ {
          label: "P", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 100_000, quantity_basis: "persons"
        } ]
      }
    ).call
    two = EvaluatePackagePrice.new(package: @package.reload, scenario: { persons: 2 }).call
    assert two.complete
    assert_equal 200_000, two.amount_minor_units
    one = EvaluatePackagePrice.new(package: @package, scenario: { persons: 1 }).call
    assert_equal 100_000, one.amount_minor_units
  end

  test "occupancy selector on bundled package price is rejected" do
    error = assert_raises(AgencyCommand::Error) do
      CreatePackagePriceDefinition.new(
        agency: @agency, actor: @actor, package: @package,
        version_lock_version: @package.editable_draft_version.lock_version,
        idempotency_key: SecureRandom.uuid,
        attributes: {
          mode: "bundled",
          components: [ {
            label: "P", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 100_000, quantity_basis: "persons", occupancy_position_key: "first"
          } ]
        }
      ).call
    end
    assert_match(/occupancy or rate-category/i, error.message)
  end

  test "service-sum adjustments appear as their own lines once" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Dinner", fulfillment_basis: "on_request" }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "per_person", amount: "50.00" }
    ).call
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: @package, offer: offer,
      version_lock_version: @package.editable_draft_version.lock_version,
      offer_version_lock_version: offer.reload.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: @package.reload,
      version_lock_version: @package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "service_sum",
        components: [ {
          label: "Early booking", client_role: "named_discount", calculation_kind: "fixed",
          amount_minor_units: 1_000, quantity_basis: "service_instances"
        } ]
      }
    ).call
    result = EvaluatePackagePrice.new(package: @package.reload, scenario: { persons: 2 }).call
    assert result.complete
    assert_equal 9_000, result.amount_minor_units
    assert result.lines.any? { |line| line.label == "Early booking" && line.signed_revenue_effect_minor_units == -1_000 }
  end

  test "manual review cancellation is not treated as zero" do
    UpdatePackageClientTerms.new(
      agency: @agency, actor: @actor, package: @package,
      version_lock_version: @package.editable_draft_version.lock_version,
      attributes: {
        cancellation_tiers: [ {
          threshold_kind: "days_before_departure", days_before: 30,
          consequence_kind: "manual_review", summary: "Staff review the file"
        } ]
      }
    ).call
    tier = @package.reload.editable_draft_version.cancellation_policy.tiers.sole
    assert tier.manual_review?
    assert_equal "Staff review the file", tier.summary
    assert_nil tier.amount_minor_units
  end

  test "choice-gated binding without activation is rejected" do
    contractor = create_capacity_supplier(@agency, "Choice Contractor")
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: contractor, provider: contractor, prefix: "Choice"
    )
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: graph[:arrangement].id,
        supplier_arrangement_version_id: graph[:version].id,
        arrangement_item_id: graph[:item].id,
        client_title: "Dinner"
      }
    ).call.record
    binding = offer.editable_draft_version.source_bindings.sole
    binding.update!(membership_kind: "choice_gated")
    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferChoices.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: offer.reload.editable_draft_version.lock_version,
        attributes: {
          groups: [ {
            name: "Dinner", min_selections: 1, max_selections: 1,
            options: [ { name: "Standard", activation: { activation_kind: "none" } } ]
          } ]
        }
      ).call
    end
    assert_match(/choice-gated source must be reachable/i, error.message)
  end

  test "package sales cap uses persons not traveler positions" do
    UpdatePackageClientTerms.new(
      agency: @agency, actor: @actor, package: @package,
      version_lock_version: @package.editable_draft_version.lock_version,
      attributes: { sales_cap_quantity: 1, sales_cap_basis: "persons" }
    ).call
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: @package.reload,
      version_lock_version: @package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "bundled",
        components: [ {
          label: "P", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 100_000, quantity_basis: "persons"
        } ]
      }
    ).call
    over = EvaluatePackagePrice.new(package: @package.reload, scenario: { persons: 2 }).call
    assert_not over.complete
    assert_match(/sales cap/i, over.blockers.first[:message])
    ok = EvaluatePackagePrice.new(package: @package, scenario: { persons: 1 }).call
    assert ok.complete
  end
end
