# frozen_string_literal: true

require "test_helper"

class M4d0OutlineCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    @departure = create_capacity_departure(@agency, name: "Outline Departure")
  end

  test "create departure requires responsible office and accepts target timing" do
    error = assert_raises(AgencyCommand::Error) do
      CreateDeparture.new(
        agency: @agency,
        actor: @actor,
        attributes: { name: "No Office", responsible_office_id: "" }
      ).call
    end
    assert_equal :invalid, error.code

    departure = CreateDeparture.new(
      agency: @agency,
      actor: @actor,
      attributes: {
        name: "Seasonal Concept",
        target_timing_text: "Late spring 2027",
        responsible_office_id: @office.id
      }
    ).call.record
    assert_equal "Late spring 2027", departure.target_timing_text
    assert_equal @office.id, departure.responsible_office_id
    assert_nil departure.starts_on
  end

  test "outline create makes undecided unowned draft with client timing" do
    offer = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Coach transfer", client_timing_text: "Day 1 afternoon" }
    ).call.record
    version = offer.editable_draft_version
    assert version.definition.undecided?
    assert_equal "Day 1 afternoon", version.definition.client_timing_text
    assert_nil version.owning_package_version_id
    assert_equal 0, version.source_bindings.count
  end

  test "explicit basis create rejects undecided" do
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferWithExplicitBasis.new(
        agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
        attributes: { name: "Nope", fulfillment_basis: "undecided" }
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "initial package with outline is atomic and idempotent" do
    key = SecureRandom.uuid
    first = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: {
        package_name: "Main stay",
        component_name: "Hotel nights",
        placement: "included",
        client_timing_text: "Nights 1–3"
      }
    ).call
    package = first.record
    version = package.editable_draft_version
    inclusion = version.inclusions.sole
    assert_equal "included", inclusion.placement
    assert inclusion.service_offer_version.definition.undecided?
    assert_equal package.id, AuditEvent.find_by(action: "package.created", subject_id: package.id).subject_id

    second = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: {
        package_name: "Main stay",
        component_name: "Hotel nights",
        placement: "included",
        client_timing_text: "Nights 1–3"
      }
    ).call
    assert_equal :replayed, second.status
    assert_equal package.id, second.record.id
    assert_equal 1, @departure.packages.count
  end

  test "inline outline create accepts undecided" do
    package = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Primary" }
    ).call.record
    version = package.editable_draft_version
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Optional meal",
        fulfillment_basis: "undecided",
        placement: "optional",
        client_timing_text: "One evening"
      }
    ).call
    offer_version = version.reload.inclusions.order(:position).last.service_offer_version
    assert offer_version.definition.undecided?
    assert_equal "One evening", offer_version.definition.client_timing_text
  end

  test "resolve fulfillment from undecided audits and blocks reverse" do
    offer = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Agency coach" }
    ).call.record
    version = offer.editable_draft_version
    ResolveServiceOfferFulfillmentBasis.new(
      agency: @agency, actor: @actor, offer: offer,
      fulfillment_basis: "agency_fulfilled",
      version_lock_version: version.lock_version
    ).call
    assert version.definition.reload.agency_fulfilled?
    assert AuditEvent.exists?(action: "service_offer.fulfillment_basis_resolved", subject_id: offer.id)

    error = assert_raises(AgencyCommand::Error) do
      ResolveServiceOfferFulfillmentBasis.new(
        agency: @agency, actor: @actor, offer: offer,
        fulfillment_basis: "on_request",
        version_lock_version: version.reload.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "publication readiness rejects undecided" do
    offer = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Pending fulfillment" }
    ).call.record
    ActivateDeparture.new(
      agency: @agency, actor: @actor, departure: @departure, lock_version: @departure.lock_version
    ).call
    readiness = EvaluateServiceOfferPublicationReadiness.new(
      agency: @agency, version: offer.editable_draft_version
    ).call
    refute readiness.ok
    assert_match(/undecided/i, readiness.issues.map(&:message).join(" "))
  end

  test "viewer cannot create outline" do
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferOutline.new(
        agency: @agency, actor: @viewer, departure: @departure, idempotency_key: SecureRandom.uuid,
        attributes: { name: "Hidden" }
      ).call
    end
    assert_equal :unauthorized, error.code
  end
end
