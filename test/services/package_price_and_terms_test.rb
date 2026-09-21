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

  test "missing required dinner choice makes package price incomplete" do
    dinner = create_choice_dinner_offer!
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: @package, offer: dinner,
      version_lock_version: @package.editable_draft_version.lock_version,
      offer_version_lock_version: dinner.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
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
    result = EvaluatePackagePrice.new(package: @package.reload, scenario: { persons: 2 }).call
    assert_not result.complete
    assert_equal :choices, result.blockers.first[:field]
  end

  test "selected deluxe option adds its price effect line" do
    dinner = create_choice_dinner_offer!(deluxe_effect: 5_000)
    deluxe = dinner.editable_draft_version.choice_options.find_by!(name: "Deluxe")
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: @package, offer: dinner,
      version_lock_version: @package.editable_draft_version.lock_version,
      offer_version_lock_version: dinner.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
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
    result = EvaluatePackagePrice.new(
      package: @package.reload,
      scenario: { persons: 2, selected_option_ids: [ deluxe.id ] }
    ).call
    assert result.complete
    assert_equal 205_000, result.amount_minor_units
    assert result.lines.any? { |line| line.label == "Deluxe" && line.signed_revenue_effect_minor_units == 5_000 }
  end

  test "raw binding id cannot activate a choice-gated source" do
    dinner = create_choice_dinner_offer!
    binding = dinner.editable_draft_version.source_bindings.find_by!(membership_kind: "choice_gated")
    collected = CollectSelectedOfferBindings.new(
      version: dinner.editable_draft_version,
      scenario: EvaluateClientPrice::Scenario.build(selected_binding_ids: [ binding.id ]),
      package_preview: true
    ).call
    assert_equal :ok, collected.status
    assert_not_includes collected.bindings.map(&:id), binding.id
  end

  test "failed dinner binding collection makes whole package economics unknown" do
    contractor = create_capacity_supplier(@agency, "Econ Contractor")
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: contractor, provider: contractor, prefix: "Econ"
    )
    coach = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: graph[:arrangement].id,
        supplier_arrangement_version_id: graph[:version].id,
        arrangement_item_id: graph[:item].id,
        client_title: "Coach"
      }
    ).call.record
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: contractor.id,
        label: "Coach zero"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @actor, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "zero_cost", zero_cost_reason: "Included", currency: "USD" }
    ).call.record
    MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @actor, definition: definition.reload,
      lock_version: definition.lock_version,
      readiness_provenance: "package economics test"
    ).call

    dinner_graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: contractor, provider: contractor, prefix: "EconDinner"
    )
    dinner = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: dinner_graph[:arrangement].id,
        supplier_arrangement_version_id: dinner_graph[:version].id,
        arrangement_item_id: dinner_graph[:item].id,
        client_title: "Dinner"
      }
    ).call.record
    binding = dinner.editable_draft_version.source_bindings.sole
    binding.update!(
      membership_kind: "alternative",
      alternative_group_key: "dinner",
      alternative_group_label: "Dinner"
    )

    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: @package, offer: coach,
      version_lock_version: @package.editable_draft_version.lock_version,
      offer_version_lock_version: coach.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: @package.reload, offer: dinner,
      version_lock_version: @package.editable_draft_version.lock_version,
      offer_version_lock_version: dinner.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    CreatePackagePriceDefinition.new(
      agency: @agency, actor: @actor, package: @package.reload,
      version_lock_version: @package.editable_draft_version.lock_version,
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
      agency: @agency, actor: @actor, package: @package.reload,
      scenario: { persons: 2 }
    ).call
    assert_equal :unknown, economics.status
    assert_match(/exactly one alternative/i, economics.reason)
    assert_nil economics.indicative_margin_minor_units
  end

  private

  def create_choice_dinner_offer!(deluxe_effect: nil)
    contractor = create_capacity_supplier(@agency, "Dinner Contractor #{SecureRandom.hex(2)}")
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: contractor, provider: contractor,
      prefix: "Dinner#{SecureRandom.hex(2)}"
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
    UpdateServiceOfferChoices.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: offer.reload.editable_draft_version.lock_version,
      attributes: {
        groups: [ {
          name: "Dinner", min_selections: 1, max_selections: 1,
          options: [
            { name: "Standard", activation: { activation_kind: "binding", service_offer_source_binding_id: binding.id } },
            {
              name: "Deluxe",
              price_effect_minor_units: deluxe_effect,
              activation: { activation_kind: "binding", service_offer_source_binding_id: binding.id }
            }
          ]
        } ]
      }
    ).call
    offer.reload
  end
end
