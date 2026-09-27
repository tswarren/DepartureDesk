# frozen_string_literal: true

require "test_helper"

class CruisePortsAndCommercialBenefitsTest < ActiveSupport::TestCase
  include CruiseCompositionHelper
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

  test "a cruise sailing may leave both ports blank" do
    definition = create_sailing.record.arrangement.versions.sole.service_occurrence_definitions.sole

    assert_nil definition.departure_port_name
    assert_nil definition.return_port_name
    assert_nil definition.description
  end

  test "named ports and itinerary notes save and one port can be cleared" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    definition = version.service_occurrence_definitions.sole

    updated = update_sailing(arrangement, version, definition, departure_port_name: "Barcelona",
      return_port_name: "Civitavecchia", description: "Sea day after leaving port")
    definition = updated.record.occurrence_definition
    assert_equal "Barcelona", definition.departure_port_name
    assert_equal "Civitavecchia", definition.return_port_name
    assert_equal "Sea day after leaving port", definition.description
    assert_equal "Celebrity group agreement", arrangement.reload.name
    assert_equal "America/New_York", definition.time_zone

    cleared = update_sailing(arrangement, version, definition, departure_port_name: "",
      return_port_name: "Civitavecchia", description: "Sea day after leaving port")
    definition = cleared.record.occurrence_definition
    assert_nil definition.departure_port_name
    assert_equal "Civitavecchia", definition.return_port_name
  end

  test "a port name longer than 160 characters is rejected" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    definition = version.service_occurrence_definitions.sole

    error = assert_raises(AgencyCommand::Error) do
      update_sailing(arrangement, version, definition, departure_port_name: "A" * 161)
    end
    assert_equal :invalid, error.code
    assert_nil definition.reload.departure_port_name
  end

  test "a non-cruise occurrence saves without port names" do
    graph = create_capacity_graph
    definition = graph[:occurrence_definition]
    assert_nil definition.departure_port_name
    assert_nil definition.return_port_name

    UpdateServiceOccurrence.new(
      agency: @agency,
      actor: @actor,
      definition: definition,
      lock_version: definition.lock_version,
      attributes: {
        name: definition.name,
        starts_on: definition.starts_on,
        ends_on: definition.ends_on,
        time_zone: definition.time_zone,
        description: "Hotel stay notes"
      }
    ).call

    definition.reload
    assert_nil definition.departure_port_name
    assert_nil definition.return_port_name
    assert_equal "Hotel stay notes", definition.description
  end

  test "Smith tour conductor and group amenity wording share one citation" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole

    tour = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    gap = record_benefit(arrangement, version.reload, "group_amenity_program", body: GAP_BODY)

    assert_equal :created, tour.status
    assert_equal :created, gap.status
    assert_equal "July 2025 Celebrity Groups brochure", tour.record.source_citation
    assert_equal "July 2025 Celebrity Groups brochure", gap.record.source_citation
    assert_equal TOUR_BODY, tour.record.body
    assert_equal GAP_BODY, gap.record.body
    assert_not_equal tour.record.supplier_arrangement_commercial_benefit_id,
      gap.record.supplier_arrangement_commercial_benefit_id
    assert_equal 2, arrangement.supplier_arrangement_commercial_benefits.count
  end

  test "a second term of the same type updates the saved wording" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    first = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    version.reload

    error = assert_raises(ActiveRecord::RecordInvalid) do
      version.supplier_arrangement_commercial_benefit_definitions.create!(
        agency: @agency,
        departure: @departure,
        supplier_arrangement: arrangement,
        supplier_arrangement_commercial_benefit: arrangement.supplier_arrangement_commercial_benefits.create!(
          agency: @agency, departure: @departure
        ),
        term_type: "tour_conductor_credit",
        body: "A second tour-conductor term"
      )
    end
    assert_match "already been taken", error.message

    revised = record_benefit(
      arrangement, version, "tour_conductor_credit",
      body: "#{TOUR_BODY} Reviewed.",
      definition: first.record
    )
    assert_equal "#{TOUR_BODY} Reviewed.", revised.record.body
    assert_equal 1, version.supplier_arrangement_commercial_benefit_definitions
      .where(term_type: "tour_conductor_credit").count
  end

  test "an invalid benefit save leaves the other term and the sailing unchanged" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    definition = version.service_occurrence_definitions.sole
    update_sailing(arrangement, version, definition, departure_port_name: "Barcelona")
    tour = record_benefit(arrangement, version.reload, "tour_conductor_credit", body: TOUR_BODY)

    error = assert_raises(AgencyCommand::Error) do
      record_benefit(arrangement, version.reload, "group_amenity_program", body: "")
    end
    assert_equal :invalid, error.code
    assert_equal TOUR_BODY, tour.record.reload.body
    assert_equal "Barcelona", definition.reload.departure_port_name
    assert_equal 0, version.supplier_arrangement_commercial_benefit_definitions
      .where(term_type: "group_amenity_program").count
  end

  test "benefit wording and citation length limits are rejected" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole

    body_error = assert_raises(AgencyCommand::Error) do
      record_benefit(arrangement, version, "tour_conductor_credit", body: "A" * 4_001)
    end
    citation_error = assert_raises(AgencyCommand::Error) do
      record_benefit(arrangement, version, "group_amenity_program", body: GAP_BODY, citation: "C" * 161)
    end
    assert_equal :invalid, body_error.code
    assert_equal :invalid, citation_error.code
    assert_equal 0, version.supplier_arrangement_commercial_benefit_definitions.count
  end

  test "saved wording on a supplier-confirmed revision cannot change in place" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    saved = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: arrangement, supplier_arrangement_version: version,
      confirming_supplier: @contractor, evidence_kind: "supplier_confirmation",
      evidence_on: Date.current, channel: "portal",
      reference_note: "Supplier approved exact terms",
      confirmed_without_identifier_reason: "Supplier did not issue one",
      actor: @actor, recorded_at: Time.current
    )

    error = assert_raises(AgencyCommand::Error) do
      record_benefit(arrangement, version.reload, "tour_conductor_credit",
        body: "Changed after confirmation", definition: saved.record)
    end
    assert_equal :invalid_state, error.code
    assert_equal TOUR_BODY, saved.record.reload.body

    added = record_benefit(arrangement, version.reload, "group_amenity_program", body: GAP_BODY)
    assert_equal GAP_BODY, added.record.body
  end

  test "activation succeeds with no commercial benefits and freezes saved wording" do
    empty = create_sailing.record.arrangement
    activate_cruise!(empty)
    assert_equal "activated", empty.versions.order(:version_number).first.status
    assert_equal 0, empty.supplier_arrangement_commercial_benefits.count

    arranged = create_sailing_named("Celebrity benefits").record.arrangement
    version = arranged.versions.sole
    tour = record_benefit(arranged, version, "tour_conductor_credit", body: TOUR_BODY)
    activate_cruise!(arranged)
    assert_equal TOUR_BODY, tour.record.reload.body

    error = assert_raises(AgencyCommand::Error) do
      record_benefit(arranged, version.reload, "tour_conductor_credit",
        body: "After activation", definition: tour.record)
    end
    assert_equal :invalid_state, error.code
    assert_equal TOUR_BODY, tour.record.reload.body
  end

  test "a successor copies benefits and abandoning it leaves the governing wording" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    tour = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    gap = record_benefit(arrangement, version.reload, "group_amenity_program", body: GAP_BODY)
    activate_cruise!(arrangement)

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: arrangement.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copied_tour = successor.supplier_arrangement_commercial_benefit_definitions
      .find_by!(term_type: "tour_conductor_credit")
    copied_gap = successor.supplier_arrangement_commercial_benefit_definitions
      .find_by!(term_type: "group_amenity_program")
    assert_equal tour.record.supplier_arrangement_commercial_benefit_id,
      copied_tour.supplier_arrangement_commercial_benefit_id
    assert_equal gap.record.id, copied_gap.copied_from_id
    assert_equal GAP_BODY, copied_gap.body

    record_benefit(arrangement, successor, "group_amenity_program",
      body: "#{GAP_BODY} Proposed change.", definition: copied_gap)
    assert_equal GAP_BODY, gap.record.reload.body
    assert_equal "#{GAP_BODY} Proposed change.", copied_gap.reload.body

    AbandonSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: arrangement.reload,
      reason: "Keep the governing wording",
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: successor.reload.lock_version
    ).call
    assert_equal "abandoned", successor.reload.status
    assert_equal GAP_BODY, gap.record.reload.body
    assert_equal "activated", arrangement.governing_version.status
  end

  test "a benefit change advances the version lock and rejects stale activation and edits" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    occurrence = version.service_occurrence_definitions.sole
    activate_departure!
    submitted_lock = version.lock_version
    arrangement_lock = arrangement.lock_version

    saved = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    assert version.reload.lock_version > submitted_lock

    activation_error = assert_raises(AgencyCommand::Error) do
      ActivateSupplierArrangementVersion.new(
        agency: @agency, actor: @actor, arrangement: arrangement, version: version,
        arrangement_lock_version: arrangement_lock,
        version_lock_version: submitted_lock,
        idempotency_key: SecureRandom.uuid,
        evidence_attributes: confirmation_evidence,
        cost_source_coverage_acknowledged: true,
        provisional_costs_acknowledged: true,
        commitment_trigger_coverage_acknowledged: true
      ).call
    end
    sailing_error = assert_raises(AgencyCommand::Error) do
      update_sailing(arrangement, version, occurrence, description: "Late note",
        version_lock_version: submitted_lock)
    end
    benefit_error = assert_raises(AgencyCommand::Error) do
      record_benefit(
        arrangement, version, "tour_conductor_credit",
        body: "#{TOUR_BODY} Amended.",
        definition: saved.record,
        version_lock_version: submitted_lock
      )
    end

    assert_equal :conflict, activation_error.code
    assert_equal :conflict, sailing_error.code
    assert_equal :conflict, benefit_error.code
    assert_equal "draft", version.reload.status
    assert_equal TOUR_BODY, saved.record.reload.body
  end

  test "a successful benefit save replays before stale locks are checked" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    submitted_lock = version.lock_version
    create_key = "benefit-replay-create"

    created = record_benefit(
      arrangement, version, "tour_conductor_credit", body: TOUR_BODY,
      version_lock_version: submitted_lock, idempotency_key: create_key
    )
    lock_after_create = version.reload.lock_version
    replayed_create = record_benefit(
      arrangement, version, "tour_conductor_credit", body: TOUR_BODY,
      version_lock_version: submitted_lock, definition_lock_version: nil,
      idempotency_key: create_key
    )
    assert_equal :replayed, replayed_create.status
    assert_equal created.record.id, replayed_create.record.id
    assert_equal lock_after_create, version.reload.lock_version
    assert_equal 1, version.supplier_arrangement_commercial_benefit_definitions.count

    update_key = "benefit-replay-update"
    update_lock = version.lock_version
    definition_lock = created.record.lock_version
    revised_body = "#{TOUR_BODY} Reviewed."
    updated = record_benefit(
      arrangement, version, "tour_conductor_credit", body: revised_body,
      definition: created.record, version_lock_version: update_lock,
      definition_lock_version: definition_lock, idempotency_key: update_key
    )
    lock_after_update = version.reload.lock_version
    replayed_update = record_benefit(
      arrangement, version, "tour_conductor_credit", body: revised_body,
      version_lock_version: update_lock, definition_lock_version: definition_lock,
      idempotency_key: update_key
    )
    assert_equal :created, updated.status
    assert_equal :replayed, replayed_update.status
    assert_equal updated.record.id, replayed_update.record.id
    assert_equal revised_body, replayed_update.record.body
    assert_equal lock_after_update, version.reload.lock_version
    assert_equal 2, AuditEvent.where(
      action: "supplier_arrangement.updated", subject_id: arrangement.id
    ).count
  end

  test "a confirmed successor is not labeled as awaiting confirmation" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    tour = record_benefit(arrangement, version, "tour_conductor_credit", body: TOUR_BODY)
    assert_equal "Draft wording for this version. The group agreement is not Supplier-confirmed.",
      cruise_benefit_revision_sentence(version.reload, tour.record)

    activate_cruise!(arrangement)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: arrangement.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    copied = successor.supplier_arrangement_commercial_benefit_definitions
      .find_by!(term_type: "tour_conductor_credit")
    amended = record_benefit(
      arrangement, successor, "tour_conductor_credit",
      body: "#{TOUR_BODY} Proposed change.", definition: copied
    ).record

    assert_equal "Proposed amendment awaiting confirmation. This is not the governing agreement.",
      cruise_benefit_revision_sentence(successor.reload, amended)

    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: arrangement,
      supplier_arrangement_version: successor, confirming_supplier: @contractor,
      evidence_kind: "supplier_confirmation", evidence_on: Date.current, channel: "portal",
      reference_note: "Supplier approved the amendment",
      confirmed_without_identifier_reason: "Supplier did not issue one",
      actor: @actor, recorded_at: Time.current
    )
    assert_equal "Recorded wording for this Supplier-confirmed revision.",
      cruise_benefit_revision_sentence(successor.reload, amended.reload)
    assert_equal "Frozen wording for this governing version.",
      cruise_benefit_revision_sentence(arrangement.governing_version, tour.record.reload)
  end

  test "another agency cannot record a commercial benefit" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    other = agencies(:cove)

    assert_raises(ActiveRecord::RecordNotFound) do
      RecordCruiseCommercialBenefit.new(
        agency: other,
        actor: agency_users(:cove_admin),
        arrangement: arrangement,
        term_type: "tour_conductor_credit",
        body: TOUR_BODY,
        source_citation: CITATION,
        version_lock_version: version.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal 0, arrangement.supplier_arrangement_commercial_benefits.count
  end

  private

  TOUR_BODY = "1 cruise-only credit per 16 qualifying full-tariff guests, double occupancy basis. " \
    "First and second guests count; third and fourth do not. A Single paying 200% counts as two. " \
    "The credit uses the average cruise fare of categories booked, excludes NCCF, government fees, and taxes, " \
    "and is net of commission. The ratio may improve to 1-per-14 with four GAP points or 1-per-12 with six."
  GAP_BODY = "Four group points, not five per traveler. Expected forty days after group creation if deposited by day thirty. " \
    "Retain at least eight staterooms. Selections before final payment. Unallocated points are forfeited at final payment " \
    "if below eight staterooms. Standard amenities apply to full-paying guests and exclude third and fourth guests unless " \
    "the amenity says otherwise. Additional points are $12.50 per point per stateroom."
  CITATION = "July 2025 Celebrity Groups brochure"

  def create_sailing
    CreateCruiseSailingSetup.new(**sailing_arguments(idempotency_key: SecureRandom.uuid)).call
  end

  def create_sailing_named(name)
    CreateCruiseSailingSetup.new(
      **sailing_arguments(idempotency_key: SecureRandom.uuid).merge(
        arrangement_attributes: {
          name: name,
          contracting_supplier_id: @contractor.id,
          supplier_contact_id: @contact.id
        }
      )
    ).call
  end

  def sailing_arguments(idempotency_key:)
    {
      agency: @agency, actor: @actor, departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Western Caribbean", starts_on: "2027-11-06", ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: idempotency_key
    }
  end

  def update_sailing(arrangement, version, definition, version_lock_version: nil, **occurrence)
    item_definition = version.arrangement_item_definitions.sole
    UpdateCruiseSailingSetup.new(
      agency: @agency, actor: @actor, arrangement: arrangement,
      arrangement_attributes: { name: arrangement.name, supplier_contact_id: @contact.id },
      item_attributes: { name: item_definition.name },
      occurrence_attributes: {
        name: definition.name, starts_on: definition.starts_on, ends_on: definition.ends_on,
        time_zone: definition.time_zone
      }.merge(occurrence),
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version_lock_version || version.reload.lock_version,
      item_lock_version: item_definition.lock_version,
      occurrence_lock_version: definition.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def record_benefit(arrangement, version, term_type, body:, citation: CITATION, definition: nil,
    version_lock_version: nil, definition_lock_version: nil, idempotency_key: SecureRandom.uuid)
    RecordCruiseCommercialBenefit.new(
      agency: @agency, actor: @actor, arrangement: arrangement,
      term_type: term_type, body: body, source_citation: citation,
      version_lock_version: version_lock_version || version.reload.lock_version,
      definition_lock_version: definition_lock_version || definition&.reload&.lock_version,
      idempotency_key: idempotency_key
    ).call
  end

  def activate_departure!
    @departure.update!(
      status: "active",
      departure_reference: @departure.departure_reference.presence ||
        "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: @departure.first_activated_at || Time.current
    )
  end

  def confirmation_evidence
    {
      evidence_kind: "supplier_confirmation", evidence_on: Date.current, channel: "portal",
      reference_note: "Supplier approved exact terms",
      confirmed_without_identifier_reason: "Supplier did not issue one"
    }
  end

  def activate_cruise!(arrangement)
    version = arrangement.versions.find_by!(status: "draft")
    item = arrangement.arrangement_items.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency, actor: @actor, arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    version.capacity_pool_definitions.find_by!(capacity_pool: cabin.record.pool).update!(
      evidence_kind: "contract", evidence_on: Date.current, evidence_reference_note: "Signed cabin block"
    )
    @departure.update!(
      status: "active",
      departure_reference: @departure.departure_reference.presence || "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: @departure.first_activated_at || Time.current
    )
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure, supplier_arrangement: arrangement,
      supplier_arrangement_version: version.reload, arrangement_item: item,
      charging_supplier: @contractor, label: "Entered cruise cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure, supplier_arrangement: arrangement,
      supplier_arrangement_version: version, supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:#{source.id}", readiness_provenance: "Signed"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure, supplier_arrangement: arrangement,
      supplier_arrangement_version: version, committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation", authority_shape: "fixed_quantity",
      description: "Guaranteed sailing", fixed_quantity: 8, quantity_basis: "resource_units", position: 1
    )
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: arrangement, version: version.reload,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current, channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call
  end
end
