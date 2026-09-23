# frozen_string_literal: true

require "test_helper"

class CruiseServiceConnectionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
  end

  test "celebrity graph connects one service with a null price effect and a stored rate key" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")

    result = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing")
    offer = result.record
    draft = offer.editable_draft_version
    option = draft.choice_options.sole

    assert_equal :created, result.status
    assert_equal "Celebrity Beyond sailing", offer.name
    assert_equal "Celebrity Beyond sailing", draft.definition.client_title
    assert_nil option.price_effect_minor_units
    assert_nil option.client_description
    assert_equal "cruise_cabin:#{option.id}", option.client_rate_category_key
    assert_equal "O1 — Prime Oceanview", option.name
    assert_equal 1, ServiceOffer.where(intended_arrangement_item_id: item.id).count
    assert_equal "binding", option.source_activation.activation_kind
    assert_equal "choice_gated", option.source_activation.service_offer_source_binding.membership_kind

    event = AuditEvent.find_by!(action: "service_offer.cruise_connection_saved", subject_id: offer.id)
    assert_equal "created", event.details["status"]
    assert_equal [ "arrangement_item_id", "service_offer_id", "service_offer_version_id", "status", "supplier_arrangement_id", "supplier_arrangement_version_id" ],
      event.details.keys.sort
    assert_equal 0, AuditEvent.where(action: "service_offer.created", subject_id: offer.id).count

    error = assert_raises(AgencyCommand::Error) do
      connect_new(arrangement, version, item, [ ocean.id ], title: "Second service")
    end
    assert_equal :conflict, error.code
    assert_equal 1, ServiceOffer.where(intended_arrangement_item_id: item.id).count
  end

  test "position replacement drops reverses and replaces categories for options and bindings" do
    arrangement, version, item, ocean, inside, verandah = cruise_with_cabins(
      "O1" => "Prime Oceanview", "I1" => "Inside", "V1" => "Verandah"
    )
    offer = connect_new(arrangement, version, item, [ ocean.id, inside.id ], title: "Cabins").record
    draft = offer.editable_draft_version
    ocean_option, inside_option = draft.choice_options.order(:position).to_a
    ocean_binding, inside_binding = draft.source_bindings.order(:position).to_a

    drop_first = update_connection(offer, version, [ inside.id ], title: "Cabins")
    draft = drop_first.record.editable_draft_version
    assert_equal [ inside_option.id ], draft.choice_options.order(:position).pluck(:id)
    assert_equal [ inside_binding.id ], draft.source_bindings.order(:position).pluck(:id)
    assert_equal [ 1 ], draft.choice_options.pluck(:position)
    assert_equal [ 1 ], draft.source_bindings.pluck(:position)

    restored = update_connection(offer, version.reload, [ ocean.id, inside.id ], title: "Cabins")
    draft = restored.record.editable_draft_version
    ocean_option = draft.choice_options.order(:position).first
    inside_option = draft.choice_options.order(:position).second
    ocean_binding = draft.source_bindings.order(:position).first
    inside_binding = draft.source_bindings.order(:position).second

    reversed = update_connection(offer, version.reload, [ inside.id, ocean.id ], title: "Cabins")
    draft = reversed.record.editable_draft_version
    assert_equal [ inside_option.id, ocean_option.id ], draft.choice_options.order(:position).pluck(:id)
    assert_equal [ inside_binding.id, ocean_binding.id ], draft.source_bindings.order(:position).pluck(:id)
    assert_equal inside_option.client_rate_category_key, draft.choice_options.find(inside_option.id).client_rate_category_key
    assert_equal "I1 — Inside", draft.choice_options.find(inside_option.id).name

    replaced = update_connection(offer, version.reload, [ verandah.id, ocean.id ], title: "Cabins")
    draft = replaced.record.editable_draft_version
    assert_not draft.choice_options.exists?(inside_option.id)
    assert_equal ocean_option.id, draft.choice_options.order(:position).second.id
    assert_equal ocean_binding.id, draft.source_bindings.order(:position).second.id
    added = draft.choice_options.order(:position).first
    assert_equal "V1 — Verandah", added.name
    assert_equal "cruise_cabin:#{added.id}", added.client_rate_category_key
    assert_not_equal ocean_option.client_rate_category_key, added.client_rate_category_key
  end

  test "update keeps the stored option name and the staff name" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Client sailing").record
    offer.update!(name: "Staff working name")
    option = offer.editable_draft_version.choice_options.sole
    ocean.definitions.find_by!(supplier_arrangement_version_id: version.id).update!(name: "Renamed oceanview")

    update_connection(offer, version, [ ocean.id ], title: "Updated client title", description: "Westbound")
    offer.reload
    option.reload
    assert_equal "Staff working name", offer.name
    assert_equal "Updated client title", offer.editable_draft_version.definition.client_title
    assert_equal "Westbound", offer.editable_draft_version.definition.client_description
    assert_equal "O1 — Prime Oceanview", option.name
    assert DetectCruiseServiceConnectionShape.new(
      agency: @agency, offer: offer, version: offer.editable_draft_version
    ).call.compatible?
  end

  test "a priced cabin choice cannot be removed" do
    arrangement, version, item, ocean, inside = cruise_with_cabins("O1" => "Prime Oceanview", "I1" => "Inside")
    offer = connect_new(arrangement, version, item, [ ocean.id, inside.id ], title: "Cabins").record
    draft = offer.editable_draft_version
    ocean_option = draft.choice_options.order(:position).first
    definition = draft.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: offer, currency: "USD", mode: "calculated"
    )
    definition.service_offer_price_components.create!(
      agency: @agency, departure: @departure, service_offer: offer, service_offer_version: draft,
      label: "Ocean fare", client_role: "base_price", calculation_kind: "unit_rate",
      amount_minor_units: 10_000, quantity_basis: "resource_units",
      client_rate_category_key: ocean_option.client_rate_category_key, position: 1
    )

    error = assert_raises(AgencyCommand::Error) do
      update_connection(offer, version, [ inside.id ], title: "Cabins")
    end
    assert_match "Remove or retarget the Client price for O1 — Prime Oceanview", error.message
    assert draft.reload.choice_options.exists?(ocean_option.id)
  end

  test "connect existing keeps the staff name timing text and an unscoped price" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    outline = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Staff cruise name", client_timing_text: "Day 1 embarkation" }
    ).call.record
    draft = outline.editable_draft_version
    draft.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: outline, currency: "USD", mode: "zero_price",
      zero_price_reason: "Included for now"
    )

    result = ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: connection_attributes(version, item, [ ocean.id ], title: "Client sailing").merge(
        mode: "existing",
        service_offer_id: outline.id,
        version_lock_version: draft.lock_version
      )
    ).call
    outline.reload
    draft = outline.editable_draft_version
    assert_equal :connected, result.status
    assert_equal "Staff cruise name", outline.name
    assert_equal "Client sailing", draft.definition.client_title
    assert_equal "Day 1 embarkation", draft.definition.client_timing_text
    assert draft.price_definition.zero_price?
    assert_nil draft.choice_options.sole.price_effect_minor_units
  end

  test "decide later claims the item without choices and resumes onto the same service" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    outlined = ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "later", title: "Smith sailing", description: "Hold the categories",
        supplier_arrangement_version_id: version.id, use_tentative_draft: true,
        arrangement_lock_version: version.lock_version, arrangement_item_id: item.id
      }
    ).call
    offer = outlined.record
    assert_equal :outlined, outlined.status
    assert_equal item.id, offer.intended_arrangement_item_id
    assert offer.editable_draft_version.definition.undecided?
    assert_equal 0, offer.editable_draft_version.choice_options.count
    event = AuditEvent.find_by!(action: "service_offer.cruise_connection_saved", subject_id: offer.id)
    assert_equal "outlined", event.details["status"]
    assert_nil event.details["supplier_arrangement_version_id"]

    resumed = ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: connection_attributes(version, item, [ ocean.id ], title: "Smith sailing").merge(
        mode: "existing",
        service_offer_id: offer.id,
        version_lock_version: offer.editable_draft_version.lock_version
      )
    ).call
    assert_equal :connected, resumed.status
    assert_equal offer.id, resumed.record.id
    assert resumed.record.editable_draft_version.definition.m3_backed?
    assert_equal 1, resumed.record.editable_draft_version.choice_options.count
  end

  test "decide later conflicts when the version selection changes and a stale lock writes nothing" do
    arrangement, version, item, _ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    key = SecureRandom.uuid
    attributes = {
      mode: "later", title: "Smith sailing", description: "Hold the categories",
      supplier_arrangement_version_id: version.id, use_tentative_draft: true,
      arrangement_lock_version: version.lock_version, arrangement_item_id: item.id
    }
    first = ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: key, attributes: attributes
    ).call
    replay = ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: key, attributes: attributes
    ).call
    assert_equal :replayed, replay.status
    assert_equal first.record.id, replay.record.id

    conflict = assert_raises(AgencyCommand::Error) do
      ConnectCruiseServiceOffer.new(
        agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: key,
        attributes: attributes.merge(use_tentative_draft: false)
      ).call
    end
    assert_equal :conflict, conflict.code
    assert_equal 1, ServiceOffer.where(intended_arrangement_item_id: item.id).count

    other_arrangement, other_version, other_item, = cruise_with_cabins({ "O2" => "Cove" }, "Second sailing")
    stale = assert_raises(AgencyCommand::Error) do
      ConnectCruiseServiceOffer.new(
        agency: @agency, actor: @actor, arrangement: other_arrangement, idempotency_key: SecureRandom.uuid,
        attributes: {
          mode: "later", title: "Stale later", description: nil,
          supplier_arrangement_version_id: other_version.id, use_tentative_draft: true,
          arrangement_lock_version: other_version.lock_version + 4, arrangement_item_id: other_item.id
        }
      ).call
    end
    assert_equal :conflict, stale.code
    assert_nil ServiceOffer.find_by(intended_arrangement_item_id: other_item.id)
    assert_nil ServiceOffer.find_by(name: "Stale later")
  end

  test "a claim that points at a different cruise than the cabin choices stays advanced" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    other_arrangement, other_version, other_item, other_ocean = cruise_with_cabins({ "I1" => "Inside" }, "Second sailing")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing").record
    draft = offer.editable_draft_version
    option = draft.choice_options.sole
    binding = draft.source_bindings.sole
    other_shape = DetectCruiseArrangementShape.new(
      agency: @agency, arrangement: other_arrangement, version: other_version
    ).call
    other_resource_definition = other_version.supplier_resource_definitions.find_by!(supplier_resource_id: other_ocean.id)
    other_pool_definition = other_version.capacity_pool_definitions.find_by!(supplier_resource_id: other_ocean.id)
    binding.update!(
      supplier_arrangement: other_arrangement,
      supplier_arrangement_version: other_version,
      arrangement_item: other_item,
      arrangement_item_definition: other_shape.item_definition,
      service_occurrence: other_shape.occurrence,
      service_occurrence_definition: other_shape.occurrence_definition,
      supplier_resource: other_ocean,
      supplier_resource_definition: other_resource_definition,
      capacity_pool: other_pool_definition.capacity_pool,
      capacity_pool_definition: other_pool_definition
    )

    detected = DetectCruiseServiceConnectionShape.new(agency: @agency, offer: offer, version: draft).call
    assert_not detected.compatible?
    assert_includes detected.reasons, "The Cruise item claim does not match the cabin choices."

    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: arrangement, version: version.reload).call
    workspace = CompileCruiseServiceConnectionWorkspace.new(
      agency: @agency, arrangement: arrangement, shape: shape
    ).call
    assert_equal :advanced, workspace.status

    error = assert_raises(AgencyCommand::Error) do
      update_connection(offer, version, [ ocean.id ], title: "Changed title")
    end
    assert_equal :invalid, error.code
    assert_equal item.id, offer.reload.intended_arrangement_item_id
    assert_equal arrangement.id, offer.intended_supplier_arrangement_id
    assert_equal option.id, draft.reload.choice_options.sole.id
    assert_equal option.client_rate_category_key, draft.choice_options.sole.client_rate_category_key
    assert_equal other_item.id, draft.source_bindings.sole.arrangement_item_id
    assert_equal "Celebrity Beyond sailing", draft.definition.client_title
  end

  test "a legacy source binding blocks a second service" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    outline = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Legacy cruise service" }
    ).call.record
    AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: outline,
      version_lock_version: outline.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        arrangement_item_id: item.id,
        membership_kind: "required"
      }
    ).call

    error = assert_raises(AgencyCommand::Error) do
      connect_new(arrangement, version.reload, item, [ ocean.id ], title: "Another service")
    end
    assert_equal :conflict, error.code
    assert_match "Legacy cruise service", error.message
    assert_nil ServiceOffer.find_by(name: "Another service")
  end

  test "generic choice commands refuse a claimed cruise service without changing it" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing").record
    option_id = offer.editable_draft_version.choice_options.sole.id
    key = offer.editable_draft_version.choice_options.sole.client_rate_category_key

    choice_error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferChoices.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: offer.editable_draft_version.lock_version,
        attributes: { groups: [ { name: "Cabin category", min_selections: 1, max_selections: 1, options: [ { name: "Replacement" } ] } ] }
      ).call
    end
    setup_error = assert_raises(AgencyCommand::Error) do
      SetupCruiseCabinChoices.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: offer.editable_draft_version.lock_version,
        option_names: [ "Replacement" ]
      ).call
    end
    assert_match "Cruise service connection", choice_error.message
    assert_match "Cruise service connection", setup_error.message
    assert_equal option_id, offer.editable_draft_version.reload.choice_options.sole.id
    assert_equal key, offer.editable_draft_version.choice_options.sole.client_rate_category_key
  end

  test "setup refuses an unclaimed obvious cruise choice graph" do
    arrangement, version, item, _ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = CreateServiceOfferOutline.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Unclaimed cruise graph" }
    ).call.record
    AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: offer.editable_draft_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version.id,
        arrangement_item_id: item.id,
        membership_kind: "choice_gated"
      }
    ).call
    draft = offer.editable_draft_version.reload
    draft.choice_groups.create!(
      agency: @agency, departure: @departure, service_offer: offer,
      name: "Cabin category", min_selections: 1, max_selections: 1, position: 1
    )

    error = assert_raises(AgencyCommand::Error) do
      SetupCruiseCabinChoices.new(
        agency: @agency, actor: @actor, offer: offer,
        version_lock_version: draft.reload.lock_version,
        option_names: [ "Replacement" ]
      ).call
    end
    assert_match "Cruise service connection", error.message
    assert_equal 1, draft.reload.choice_groups.count
    assert_equal 0, draft.choice_options.count
    assert_nil offer.reload.intended_arrangement_item_id
  end

  test "graph copy keeps the stored rate key and discard clears only an abandoned claim" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing").record
    draft = offer.editable_draft_version
    key = draft.choice_options.sole.client_rate_category_key
    draft.update!(status: "published", published_at: Time.current)
    offer.update!(current_published_version: draft)
    successor = offer.versions.create!(
      agency: @agency, departure: @departure, version_number: 2, status: "draft", copied_from_version: draft
    )
    OfferVersionGraphCopy.copy_service_offer_version!(
      agency: @agency, departure: @departure, offer: offer, from: draft, to: successor
    )
    copied = successor.choice_options.sole
    assert_equal key, copied.client_rate_category_key
    assert_not_equal draft.choice_options.sole.id, copied.id

    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer, reason: "Successor not needed",
      offer_lock_version: offer.reload.lock_version,
      version_lock_version: successor.reload.lock_version
    ).call
    assert_equal item.id, offer.reload.intended_arrangement_item_id

    published_error = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOffer.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offers SET intended_arrangement_item_id = NULL, intended_supplier_arrangement_id = NULL WHERE id = ?",
            offer.id
          ])
        )
      end
    end
    assert_match(/cleared only when every version is abandoned/i, published_error.message)
  end

  test "claim constraints reject reassignment blank keys and a second item claim" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing").record
    option = offer.editable_draft_version.choice_options.sole

    reassignment = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOffer.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offers SET intended_arrangement_item_id = ? WHERE id = ?",
            SecureRandom.uuid, offer.id
          ])
        )
      end
    end
    assert_match(/cannot be reassigned/i, reassignment.message)

    blank_key = assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOfferChoiceOption.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE service_offer_choice_options SET client_rate_category_key = '   ' WHERE id = ?",
            option.id
          ])
        )
      end
    end
    assert_match(/rate_key/i, blank_key.message)

    DiscardServiceOfferDraft.new(
      agency: @agency, actor: @actor, offer: offer, reason: "Start over",
      offer_lock_version: offer.lock_version,
      version_lock_version: offer.editable_draft_version.lock_version
    ).call
    assert_nil offer.reload.intended_arrangement_item_id
    assert_nil offer.intended_supplier_arrangement_id
  end

  test "typed cabin pool predicate is shared by the helper and the compiler" do
    _arrangement, version, _item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    pool_definition = version.capacity_pool_definitions.find_by!(supplier_resource_id: ocean.id)
    helper = Object.new.extend(CruiseCompositionHelper)
    assert CruiseCabinCategorySupport.typed_cabin_pool?(pool_definition.capacity_pool, pool_definition)
    assert helper.cruise_typed_cabin_pool?(pool_definition.capacity_pool, pool_definition)
    assert_not CruiseCabinCategorySupport.typed_cabin_pool?(pool_definition.capacity_pool, nil)
    assert_not helper.cruise_typed_cabin_pool?(nil, pool_definition)
  end

  test "stale lock and a service draft update do not move the claim" do
    arrangement, version, item, ocean = cruise_with_cabins("O1" => "Prime Oceanview")
    offer = connect_new(arrangement, version, item, [ ocean.id ], title: "Celebrity Beyond sailing").record
    error = assert_raises(AgencyCommand::Error) do
      update_connection(offer, version, [ ocean.id ], title: "Changed", lock_version: offer.editable_draft_version.lock_version + 5)
    end
    assert_equal :conflict, error.code
    assert_equal "Celebrity Beyond sailing", offer.editable_draft_version.definition.reload.client_title

    previous_lock = offer.editable_draft_version.lock_version
    update_connection(offer, version, [ ocean.id ], title: "First save")
    stale_after_edit = assert_raises(AgencyCommand::Error) do
      update_connection(offer, version.reload, [ ocean.id ], title: "Second save", lock_version: previous_lock)
    end
    assert_equal :conflict, stale_after_edit.code
    assert_equal "First save", offer.editable_draft_version.definition.reload.client_title

    draft_error = assert_raises(AgencyCommand::Error) do
      UpdateServiceOfferDraft.new(
        agency: @agency, actor: @actor, offer: offer,
        offer_lock_version: offer.lock_version,
        version_lock_version: offer.editable_draft_version.lock_version,
        attributes: { name: "Renamed", intended_arrangement_item_id: nil }
      ).call
    end
    assert_match "cannot be changed", draft_error.message
    assert_equal item.id, offer.reload.intended_arrangement_item_id
  end

  private

  def cruise_with_cabins(cabins, arrangement_name = "Celebrity group agreement")
    sailing = CreateCruiseSailingSetup.new(**sailing_arguments(name: arrangement_name)).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    item = sailing.record.item
    resources = cabins.map do |code, name|
      created = CreateCruiseCabinCategorySetup.new(
        agency: @agency, actor: @actor, arrangement: arrangement,
        resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
        pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
        version_lock_version: version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
      created.record.resource
    end
    [ arrangement, version.reload, item, *resources ]
  end

  def connect_new(arrangement, version, item, resource_ids, title:)
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: connection_attributes(version, item, resource_ids, title: title).merge(mode: "new")
    ).call
  end

  def update_connection(offer, version, resource_ids, title:, description: nil, lock_version: nil)
    UpdateCruiseServiceConnection.new(
      agency: @agency, actor: @actor, offer: offer,
      attributes: {
        title: title,
        description: description,
        supplier_resource_ids: resource_ids,
        arrangement_lock_version: version.lock_version,
        version_lock_version: lock_version || offer.editable_draft_version.lock_version
      }
    ).call
  end

  def connection_attributes(version, item, resource_ids, title:)
    {
      title: title,
      supplier_arrangement_version_id: version.id,
      use_tentative_draft: true,
      arrangement_lock_version: version.lock_version,
      arrangement_item_id: item.id,
      supplier_resource_ids: resource_ids
    }
  end

  def sailing_arguments(name: "Celebrity group agreement")
    {
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: name,
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    }
  end
end
