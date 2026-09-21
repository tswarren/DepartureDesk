require "test_helper"

class PublishOfferVersionsTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M4D Publish Departure", status: "draft")
    ActivateDeparture.new(
      agency: @agency, actor: @actor, departure: @departure,
      lock_version: @departure.lock_version
    ).call
    @departure.reload
  end

  test "publishes standalone on-request service and replays idempotently" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Coach", fulfillment_basis: "on_request" }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "fixed_per_service", amount: "100.00" }
    ).call
    key = SecureRandom.uuid
    first = PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: key
    ).call
    assert_equal :created, first.status
    assert first.record.published?
    assert offer.reload.current_published_version_id == first.record.id
    assert first.record.sales_state.sales_enabled
    assert first.record.publication_manifest.present?

    second = PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: first.record.lock_version,
      idempotency_key: key
    ).call
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
  end

  test "publishes package with owned service atomically" do
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Weekend" }
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
    package.reload
    assert package.editable_draft_version.present?, "expected draft after price create"

    key = SecureRandom.uuid
    result = PublishPackageVersion.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: key
    ).call
    assert_equal :created, result.status
    assert result.record.published?
    owned = result.record.owned_service_offer_versions
    assert owned.all?(&:published?)
    assert PackagePublicationResult.exists?(package_version_id: result.record.id)

    replay = PublishPackageVersion.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: result.record.lock_version,
      idempotency_key: key
    ).call
    assert_equal :replayed, replay.status
    assert_equal result.record.id, replay.record.id
  end

  test "null choice price effect blocks package publish" do
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Choices" }
    ).call.record
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Dinner", fulfillment_basis: "on_request", placement: "included" }
    ).call
    sov = package.reload.editable_draft_version.owned_service_offer_versions.sole
    UpdateServiceOfferChoices.new(
      agency: @agency, actor: @actor, offer: sov.service_offer,
      version_lock_version: sov.lock_version,
      attributes: {
        groups: [ {
          name: "Dinner style", min_selections: 1, max_selections: 1,
          options: [ { name: "Standard", price_effect_minor_units: nil } ]
        } ]
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

    error = assert_raises(AgencyCommand::Error) do
      PublishPackageVersion.new(
        agency: @agency, actor: @actor, package: package.reload,
        version_lock_version: package.editable_draft_version.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_match(/included price|surcharge/i, error.message)
    assert package.reload.editable_draft_version.draft?
  end

  test "direct SQL cannot mutate publication manifests" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Transfers", fulfillment_basis: "agency_fulfilled" }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "fixed_per_service", amount: "25.00" }
    ).call
    published = PublishServiceOfferVersion.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    manifest = published.publication_manifest

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(<<~SQL)
        UPDATE service_offer_publication_manifests
        SET fingerprint_json = '{"tampered":true}'::jsonb
        WHERE id = '#{manifest.id}'
      SQL
    end
  end
end
