require "test_helper"

class PackageCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Package Contractor")
    @departure = create_capacity_departure(@agency, name: "Package Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Pkg"
    )
  end

  test "create package draft and replay the same idempotency key" do
    key = SecureRandom.uuid
    first = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: { name: "Vineyard weekend" }
    ).call
    second = CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: { name: "Vineyard weekend" }
    ).call
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
    assert first.record.editable_draft_version.draft?
    assert AuditEvent.exists?(action: "package.created", subject_type: "Package", subject_id: first.record.id)
  end

  test "viewer cannot create a package" do
    error = assert_raises(AgencyCommand::Error) do
      CreatePackageDraft.new(
        agency: @agency, actor: @viewer, departure: @departure, idempotency_key: SecureRandom.uuid,
        attributes: { name: "Hidden" }
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "inline create from source owns the new draft" do
    package = create_package
    result = CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: source_attrs.merge(client_title: "Dinner")
    ).call
    inclusion = result.record.editable_draft_version.inclusions.sole
    offer_version = inclusion.service_offer_version
    assert inclusion.inline_create?
    assert_equal package.editable_draft_version.id, offer_version.owning_package_version_id
    assert offer_version.definition.m3_backed?
  end

  test "inline create replays without a stray service draft" do
    package = create_package
    key = SecureRandom.uuid
    attrs = source_attrs.merge(client_title: "Coach")
    first = CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: key, attributes: attrs
    ).call
    second = CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package.reload,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: key, attributes: attrs
    ).call
    assert_equal :replayed, second.status
    assert_equal 1, package.reload.editable_draft_version.inclusions.count
    assert_equal 1, first.record.editable_draft_version.inclusions.count
  end

  test "adopt draft sets owner and rejects abandoned versions" do
    package = create_package
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Standalone dinner", fulfillment_basis: "on_request" }
    ).call.record
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: package, offer: offer,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    adopted = offer.reload.editable_draft_version
    assert_equal package.editable_draft_version.id, adopted.owning_package_version_id
    assert adopted.package_inclusions.sole.adopted_draft?

    abandoned = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Abandoned dinner", fulfillment_basis: "on_request" }
    ).call.record
    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: abandoned, reason: "Not selling",
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

  test "detach adopted draft clears owner without abandoning the package" do
    package = create_package
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Detach me", fulfillment_basis: "agency_fulfilled" }
    ).call.record
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: package, offer: offer,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    inclusion = package.reload.editable_draft_version.inclusions.sole
    DetachAdoptedServiceOfferDraft.new(
      agency: @agency, actor: @actor, package: package, inclusion: inclusion,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: offer.reload.editable_draft_version.lock_version
    ).call
    assert_nil offer.reload.editable_draft_version.owning_package_version_id
    assert package.reload.editable_draft_version.draft?
    assert_equal 0, package.editable_draft_version.inclusions.count
  end

  test "abandon package cascade-abandons inline creates and reverts adopted drafts" do
    package = create_package
    CreatePackageInlineServiceOffer.new(
      agency: @agency, actor: @actor, package: package,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Inline insurance", fulfillment_basis: "agency_fulfilled" }
    ).call
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Adopted hotel", fulfillment_basis: "on_request" }
    ).call.record
    AdoptServiceOfferDraftAsPackageOnly.new(
      agency: @agency, actor: @actor, package: package.reload, offer: offer,
      version_lock_version: package.editable_draft_version.lock_version,
      offer_version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    inline_version = package.reload.editable_draft_version.inclusions.find_by(origin: "inline_create").service_offer_version
    AbandonPackageDraft.new(
      agency: @agency, actor: @actor, package: package, reason: "Not offering",
      package_lock_version: package.lock_version,
      version_lock_version: package.editable_draft_version.lock_version
    ).call
    assert package.versions.find_by(status: "abandoned").abandoned?
    assert inline_version.reload.abandoned?
    assert_equal package.versions.find_by(status: "abandoned").id, inline_version.owning_package_version_id
    assert offer.reload.editable_draft_version.draft?
    assert_nil offer.editable_draft_version.owning_package_version_id
  end

  test "include published reusable pins without owning" do
    package = create_package
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Published coach", fulfillment_basis: "on_request" }
    ).call.record
    published = insert_published_version(offer)
    IncludePublishedReusableServiceOfferVersion.new(
      agency: @agency, actor: @actor, package: package, offer_version: published,
      version_lock_version: package.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    inclusion = package.reload.editable_draft_version.inclusions.sole
    assert inclusion.published_reusable?
    assert_nil published.reload.owning_package_version_id
  end

  test "foreign package id is not found" do
    error = assert_raises(AgencyCommand::Error) do
      CreatePackageInlineServiceOffer.new(
        agency: @agency, actor: @actor, package: SecureRandom.uuid,
        version_lock_version: 0, idempotency_key: SecureRandom.uuid,
        attributes: { client_title: "Nope", fulfillment_basis: "on_request" }
      ).call
    end
    assert_equal :not_found, error.code
  end

  private

  def create_package
    CreatePackageDraft.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Weekend package" }
    ).call.record
  end

  def source_attrs
    {
      supplier_arrangement_id: @graph[:arrangement].id,
      supplier_arrangement_version_id: @graph[:version].id,
      arrangement_item_id: @graph[:item].id,
      service_occurrence_id: @graph[:occurrence].id,
      supplier_resource_id: @graph[:resource].id
    }
  end

  def insert_published_version(offer)
    id = SecureRandom.uuid
    now = Time.current
    ServiceOfferVersion.connection.insert(<<~SQL)
      INSERT INTO service_offer_versions (
        id, agency_id, departure_id, service_offer_id, version_number, status,
        lock_version, created_at, updated_at
      ) VALUES (
        #{ServiceOfferVersion.connection.quote(id)},
        #{ServiceOfferVersion.connection.quote(@agency.id)},
        #{ServiceOfferVersion.connection.quote(@departure.id)},
        #{ServiceOfferVersion.connection.quote(offer.id)},
        2, 'published', 0,
        #{ServiceOfferVersion.connection.quote(now)},
        #{ServiceOfferVersion.connection.quote(now)}
      )
    SQL
    offer.versions.find(id)
  end
end
