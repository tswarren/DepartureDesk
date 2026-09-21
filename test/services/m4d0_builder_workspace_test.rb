# frozen_string_literal: true

require "test_helper"

class M4d0BuilderWorkspaceTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Builder Journey")
  end

  test "empty builder recommends first component" do
    readiness = EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call
    recommendation = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness
    ).call
    assert_equal :no_components, recommendation.finding.code
  end

  test "mixed outline journey builds package cards and blocks undecided publish" do
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        package_name: @departure.name,
        component_name: "Coach",
        placement: "included",
        client_timing_text: "Day 1"
      }
    ).call.record
    version = package.editable_draft_version
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Hotel", fulfillment_basis: "undecided", placement: "included" }
    ).call
    version.reload
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Optional meal", fulfillment_basis: "undecided", placement: "optional" }
    ).call

    hotel = package.editable_draft_version.inclusions.joins(:service_offer).find { |row| row.service_offer.name == "Hotel" }
    SetupHotelRoomChoices.new(
      agency: @agency, actor: @actor, offer: hotel.service_offer,
      version_lock_version: hotel.service_offer_version.lock_version
    ).call
    assert_equal "Room category", hotel.service_offer_version.reload.choice_groups.sole.name

    coach = package.editable_draft_version.inclusions.joins(:service_offer).find { |row| row.service_offer.name == "Coach" }
    ResolveServiceOfferFulfillmentBasis.new(
      agency: @agency, actor: @actor, offer: coach.service_offer,
      fulfillment_basis: "agency_fulfilled",
      version_lock_version: coach.service_offer_version.lock_version
    ).call

    workspace = DepartureBuilderWorkspace.new(agency: @agency, departure: @departure.reload)
    assert_equal 3, workspace.component_cards.size
    assert workspace.recommendation.present?

    scenarios = DeriveCommonPackageScenarios.new(agency: @agency, package: package.reload).call
    refute scenarios.summaries.first.complete
    assert scenarios.summaries.first.missing_inputs.any?

    ActivateDeparture.new(
      agency: @agency, actor: @actor, departure: @departure, lock_version: @departure.lock_version
    ).call
    readiness = EvaluatePackagePublicationReadiness.new(
      agency: @agency, version: package.editable_draft_version
    ).call
    refute readiness.ok
    assert_match(/undecided|fulfillment|price|definition/i, readiness.issues.map(&:message).join(" "))
  end

  test "reorder inclusions through command preserves package identity" do
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "A", placement: "included" }
    ).call.record
    version = package.editable_draft_version
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { name: "B", fulfillment_basis: "undecided", placement: "included" }
    ).call
    version.reload
    ids = version.inclusions.order(:position).pluck(:id)
    ReorderPackageInclusions.new(
      agency: @agency, actor: @actor, package: package,
      ordered_ids: ids.reverse, version_lock_version: version.lock_version
    ).call
    assert_equal ids.reverse, version.reload.inclusions.order(:position).pluck(:id)
  end
end
