require "test_helper"

class ServiceOfferCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Offer Contractor")
    @departure = create_capacity_departure(@agency, name: "Offer Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Offer"
    )
  end

  test "create from source prefills client title and does not copy cost" do
    result = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: source_attrs.merge(client_title: "Client cabin")
    ).call
    offer = result.record
    version = offer.editable_draft_version
    assert_equal "draft", version.status
    assert_equal "Client cabin", version.definition.client_title
    assert version.definition.m3_backed?
    binding = version.source_bindings.sole
    assert_equal @graph[:item].id, binding.arrangement_item_id
    assert_equal @graph[:version].id, binding.supplier_arrangement_version_id
    assert_nil offer.attributes["price_minor_units"]
    assert AuditEvent.exists?(action: "service_offer.created", subject_type: "ServiceOffer", subject_id: offer.id)
  end

  test "create from source replays the same idempotency key" do
    key = SecureRandom.uuid
    first = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: source_attrs.merge(client_title: "Replay")
    ).call
    second = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: source_attrs.merge(client_title: "Replay")
    ).call
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id
  end

  test "conflicting idempotency payload is rejected" do
    key = SecureRandom.uuid
    CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      attributes: source_attrs.merge(client_title: "One")
    ).call
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferFromSource.new(
        agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
        attributes: source_attrs.merge(client_title: "Two")
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "explicit basis creates no arrangement pin" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Insurance desk", fulfillment_basis: "agency_fulfilled" }
    ).call.record
    assert offer.editable_draft_version.definition.agency_fulfilled?
    assert_equal 0, offer.editable_draft_version.source_bindings.count
  end

  test "viewer cannot create an unpublished offer" do
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferWithExplicitBasis.new(
        agency: @agency, actor: @viewer, departure: @departure, idempotency_key: SecureRandom.uuid,
        attributes: { client_title: "Hidden", fulfillment_basis: "on_request" }
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "two successive definition edits from the same starting version conflict" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Original title", fulfillment_basis: "on_request" }
    ).call.record
    version = offer.editable_draft_version
    starting_offer_lock = offer.lock_version
    starting_version_lock = version.lock_version

    UpdateServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer,
      attributes: { client_title: "First edit" },
      offer_lock_version: starting_offer_lock,
      version_lock_version: starting_version_lock
    ).call
    assert_equal "First edit", version.definition.reload.client_title
    assert_operator version.reload.lock_version, :>, starting_version_lock

    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferDraft.new(
        agency: @agency, actor: @actor, offer: offer,
        attributes: { client_title: "Second edit" },
        offer_lock_version: starting_offer_lock,
        version_lock_version: starting_version_lock
      ).call
    end
    assert_equal :conflict, error.code
    assert_equal "First edit", version.definition.reload.client_title
  end

  test "reselect moves a pin to the current governing activated source and keeps Client text" do
    activated = build_activated_unestablished_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor,
      actor: @actor, prefix: "Reselect"
    )
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: activated[:arrangement].id,
        arrangement_item_id: activated[:item].id,
        client_title: "Keep this title",
        client_description: "Keep this description"
      }
    ).call.record
    assert_equal activated[:version].id,
      offer.editable_draft_version.source_bindings.sole.supplier_arrangement_version_id

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: activated[:arrangement],
      arrangement_lock_version: activated[:arrangement].reload.lock_version,
      version_lock_version: activated[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    now = Time.current
    activated[:version].reload.update!(status: "superseded", superseded_at: now)
    successor.update!(status: "activated", activated_at: now)
    activated[:arrangement].reload.update!(governing_version: successor)

    UpdateServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer,
      attributes: {
        client_title: "Keep this title",
        client_description: "Keep this description",
        reselect_current_sources: true
      },
      offer_lock_version: offer.lock_version,
      version_lock_version: offer.editable_draft_version.lock_version
    ).call

    binding = offer.editable_draft_version.reload.source_bindings.sole
    definition = offer.editable_draft_version.definition.reload
    assert_equal successor.id, binding.supplier_arrangement_version_id
    assert_equal successor.arrangement_item_definitions.find_by!(arrangement_item_id: activated[:item].id).id,
      binding.arrangement_item_definition_id
    assert_equal "Keep this title", definition.client_title
    assert_equal "Keep this description", definition.client_description
  end

  test "departed departure cannot add a source binding" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: source_attrs.merge(client_title: "Primary")
    ).call.record
    extra = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Late"
    )
    @departure.update!(
      status: "departed",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: 1.week.ago,
      departed_at: Time.current
    )
    error = assert_raises(AgencyCommand::Error) do
      AddServiceOfferSourceBinding.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: offer.editable_draft_version.lock_version,
        idempotency_key: SecureRandom.uuid,
        attributes: {
          supplier_arrangement_id: extra[:arrangement].id,
          supplier_arrangement_version_id: extra[:version].id,
          arrangement_item_id: extra[:item].id,
          membership_kind: "required"
        }
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_equal 1, offer.editable_draft_version.reload.source_bindings.count
  end

  test "binding add replays the same key even when the submitted version lock is stale" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: source_attrs.merge(client_title: "Primary")
    ).call.record
    extra = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "ReplayBind"
    )
    key = SecureRandom.uuid
    starting_lock = offer.editable_draft_version.lock_version
    attrs = {
      supplier_arrangement_id: extra[:arrangement].id,
      supplier_arrangement_version_id: extra[:version].id,
      arrangement_item_id: extra[:item].id,
      membership_kind: "required"
    }
    first = AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: starting_lock,
      idempotency_key: key,
      attributes: attrs
    ).call
    replay = AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: starting_lock,
      idempotency_key: key,
      attributes: attrs
    ).call
    assert_equal :replayed, replay.status
    assert_equal first.record.id, replay.record.id
    assert_equal 2, offer.editable_draft_version.reload.source_bindings.count

    error = assert_raises(AgencyCommand::Error) do
      AddServiceOfferSourceBinding.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: starting_lock,
        idempotency_key: key,
        attributes: attrs.merge(membership_kind: "alternative", alternative_group_key: "g1", alternative_group_label: "Group")
      ).call
    end
    assert_equal :conflict, error.code
  end

  test "stale version is a recoverable conflict" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Stale", fulfillment_basis: "on_request" }
    ).call.record
    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferDraft.new(
        agency: @agency, actor: @actor, offer: offer,
        attributes: { client_title: "Changed" },
        offer_lock_version: offer.lock_version,
        version_lock_version: offer.editable_draft_version.lock_version - 1
      ).call
    end
    assert_equal :conflict, error.code
    assert_equal "Stale", offer.editable_draft_version.definition.reload.client_title
  end

  test "actor recheck rejects a viewer on offer-only update" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Recheck", fulfillment_basis: "on_request" }
    ).call.record
    error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferDraft.new(
        agency: @agency, actor: @viewer, offer: offer,
        attributes: { client_title: "Nope" },
        offer_lock_version: offer.lock_version,
        version_lock_version: offer.editable_draft_version.lock_version
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "discard retains the number and a later draft uses a new identity" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Discard me", fulfillment_basis: "on_request" }
    ).call.record
    version = offer.editable_draft_version
    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer, reason: "Changed plans",
      offer_lock_version: offer.lock_version, version_lock_version: version.lock_version
    ).call
    assert_nil offer.reload.editable_draft_version
    assert_equal "abandoned", version.reload.status
    assert_equal 1, version.version_number
    assert AuditEvent.exists?(action: "service_offer.discarded", subject_id: offer.id)
  end

  test "departed departure cannot create an offer" do
    @departure.update!(
      status: "departed",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: 1.week.ago,
      departed_at: Time.current
    )
    error = assert_raises(AgencyCommand::Error) do
      CreateServiceOfferWithExplicitBasis.new(
        agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
        attributes: { client_title: "Too late", fulfillment_basis: "on_request" }
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "add and remove source bindings keep one required source on an M3-backed draft" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: source_attrs.merge(client_title: "Primary")
    ).call.record
    extra = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Extra"
    )
    added = AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: extra[:arrangement].id,
        supplier_arrangement_version_id: extra[:version].id,
        arrangement_item_id: extra[:item].id,
        membership_kind: "required"
      }
    ).call.record
    assert_equal 2, offer.editable_draft_version.reload.source_bindings.count
    assert AuditEvent.exists?(action: "service_offer.source_binding_added", subject_id: offer.id)

    RemoveServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer, binding: added,
      version_lock_version: offer.editable_draft_version.lock_version
    ).call
    assert_equal 1, offer.editable_draft_version.reload.source_bindings.count

    remaining = offer.editable_draft_version.source_bindings.sole
    error = assert_raises(AgencyCommand::Error) do
      RemoveServiceOfferSourceBinding.new(
        agency: @agency, actor: @actor, offer: offer, binding: remaining,
        version_lock_version: offer.editable_draft_version.lock_version
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "active arrangement create defaults to the governing activated version" do
    activated = build_activated_unestablished_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor,
      actor: @actor, prefix: "Governing"
    )
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: activated[:arrangement],
      arrangement_lock_version: activated[:arrangement].reload.lock_version,
      version_lock_version: activated[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    defaulted = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: activated[:arrangement].id,
        arrangement_item_id: activated[:item].id,
        client_title: "Governing pin"
      }
    ).call.record
    assert_equal activated[:version].id,
      defaulted.editable_draft_version.source_bindings.sole.supplier_arrangement_version_id

    tentatived = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: activated[:arrangement].id,
        supplier_arrangement_version_id: successor.id,
        use_tentative_draft: true,
        arrangement_item_id: activated[:item].id,
        client_title: "Tentative pin"
      }
    ).call.record
    assert_equal successor.id,
      tentatived.editable_draft_version.source_bindings.sole.supplier_arrangement_version_id
  end

  private

  def source_attrs
    {
      supplier_arrangement_id: @graph[:arrangement].id,
      supplier_arrangement_version_id: @graph[:version].id,
      arrangement_item_id: @graph[:item].id,
      service_occurrence_id: @graph[:occurrence].id,
      supplier_resource_id: @graph[:resource].id
    }
  end
end
