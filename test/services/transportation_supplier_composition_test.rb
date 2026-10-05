# frozen_string_literal: true

require "test_helper"

class TransportationSupplierCompositionTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "ABC Motorcoach" },
      categories: [ "ground_transportation" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @admin,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 3),
        ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "ABC Motorcoach", contracting_supplier_id: @supplier.id }
    ).call.record
  end

  test "two segments store endpoints, pickup-only times, a ceiling of three, and draft forecasts" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    port = save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    version = draft

    assert_equal [ "Hotel → Port", "Port → Airport" ], version.arrangement_item_definitions.order(:position).pluck(:name)
    assert_not version.arrangement_item_definitions.exists?(name: "Airport → Port")
    hotel_occurrence = version.service_occurrence_definitions.find_by!(arrangement_item: hotel)
    assert_equal "Hilton Fort Lauderdale Marina", hotel_occurrence.origin_name
    assert_nil hotel_occurrence.ends_at_local
    assert_nil hotel_occurrence.departure_port_name
    pool = version.capacity_pool_definitions.find_by!(arrangement_item: hotel)
    assert_equal 1, pool.proposed_opening_quantity
    assert_equal 3, pool.maximum_total_resource_units
    assert_equal "motorcoaches", pool.unit_label
    assert_equal 15, version.supplier_resource_definitions.find_by!(arrangement_item: hotel).maximum_occupancy
    assert_equal [ "unspecified" ], version.supplier_cost_definitions.pluck(:commission_treatment).uniq
    assert_equal 37_500, forecast_total
    assert_equal hotel.default_service_provider_id, @supplier.id if hotel.respond_to?(:default_service_provider_id)

    save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03", item: hotel, confirmed: 2, ceiling: 3)
    assert_equal 57_500, forecast_total
    assert_equal 2, draft.supplier_cost_usage_assumptions.find_by!(arrangement_item: hotel).expected_resource_units
    assert_equal port.id, port.id
  end

  test "activation bills established and increased coaches and ignores a release" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    confirm!
    activate!
    version = @arrangement.reload.governing_version
    assert_equal 37_500, forecast_total(version)
    assert_equal 37_500, amount_due(version).total_minor_units

    change!(hotel, "increased", charter_today)
    version = @arrangement.reload.governing_version
    assert_equal 40_000, segment_exposure(version, hotel)
    assert_equal 17_500, segment_exposure(version, other_item(hotel))
    assert_equal 57_500, forecast_total(version)
    assert_equal 57_500, amount_due(version).total_minor_units
    assert_equal [ 40_000, 17_500 ], amount_due(version).lines.map(&:amount_minor_units)

    travel_to(charter_today.in_time_zone("America/New_York").change(hour: 12) + 2.days) do
      change!(hotel, "increased", Date.current + 30)
      assert_equal 57_500, forecast_total(@arrangement.reload.governing_version)
      assert_equal 77_500, amount_due(@arrangement.reload.governing_version).total_minor_units
    end

    change!(hotel, "released", charter_today)
    version = @arrangement.reload.governing_version
    assert_equal 1, version.capacity_pool_definitions.find_by!(arrangement_item: hotel).capacity_pool.capacity_projection.current_supplier_capacity
    assert_equal 40_000, segment_exposure(version, hotel)
    assert_equal 77_500, amount_due(version).total_minor_units
    review = compile(version)
    assert review.clarifications.any? { |note| note.code == "release" }
    assert_not review.clarifications.any? { |note| note.code == "late_coach" }
  end

  test "a later-recorded earlier coach recomputes the amount due and a post-due coach does not" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    port = save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    confirm!
    activate!
    change!(hotel, "increased", charter_today)
    travel_to Time.zone.parse("2027-11-07 12:00") do
      change!(hotel, "increased", Date.new(2027, 11, 6))
      version = @arrangement.reload.governing_version
      assert_equal 57_500, amount_due(version).total_minor_units
      assert compile(version).clarifications.any? { |note| note.code == "late_coach" }
      assert_operator forecast_total(version), :>, 57_500

      change!(port, "increased", Date.new(2027, 11, 2))
      version = @arrangement.reload.governing_version
      lines = amount_due(version).lines.map(&:amount_minor_units)
      assert_equal 35_000, lines.last
      assert_includes lines, 40_000
    end
  end

  test "confirmation freezes agreement facts and still allows a coach change and final-count completion" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    confirm!
    occurrence = draft.service_occurrence_definitions.find_by!(arrangement_item: hotel)
    assert_raises(ActiveRecord::RecordInvalid) { occurrence.update!(origin_name: "Changed pickup") }
    activate!
    before = amount_due(@arrangement.reload.governing_version).total_minor_units
    confirmation = @arrangement.supplier_confirmations.order(:recorded_at).last
    commitments = SupplierCommitment.with_current_disposition_state.where(supplier_arrangement: @arrangement).select(&:open_state?)
    assert commitments.any?
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, confirmation:,
      commitment_ids: commitments.map(&:id), outcome: "satisfied", idempotency_key: SecureRandom.uuid
    ).call
    assert_equal before, amount_due(@arrangement.reload.governing_version).total_minor_units
    assert_equal 1, @arrangement.governing_version.capacity_pool_definitions.find_by!(arrangement_item: hotel).capacity_pool.capacity_projection.current_supplier_capacity
  end

  test "an unfinished hotel item blocks transportation confirmation and stays editable" do
    save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    lodging = add_lodging_stay

    error = assert_raises(AgencyCommand::Error) { confirm! }
    assert_equal "Advanced Supplier planning", error.message
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: draft.id)

    lodging.fetch(:occurrence_definition).update!(name: "Changed stay")
    assert_equal "Changed stay", lodging.fetch(:occurrence_definition).reload.name
  end

  test "a second resource-unit source stays advanced and is not rewritten" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    port = save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    original = component_for(draft, hotel)
    extra = add_second_source(hotel)
    due_before = amount_due(draft).total_minor_units

    error = assert_raises(AgencyCommand::Error) do
      save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "250", final_count: "2027-11-03", item: hotel, confirmed: 1, ceiling: 3)
    end
    assert_equal "Advanced Supplier planning", error.message
    assert_equal 20_000, original.reload.amount_minor_units
    assert_equal 5_000, extra.reload.amount_minor_units
    assert_equal 17_500, component_for(draft, port).amount_minor_units

    error = assert_raises(AgencyCommand::Error) do
      SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    end
    assert_equal "Advanced Supplier planning", error.message
    assert_equal due_before, amount_due(draft).total_minor_units

    error = assert_raises(AgencyCommand::Error) { confirm! }
    assert_equal "Advanced Supplier planning", error.message
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: draft.id)
  end

  test "a capacity-backed rate cannot point at another arrangement or another segment" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    port = save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    component = component_for(draft, hotel)
    other_arrangement = CreateSupplierArrangement.new(
      agency: @agency, actor: @admin, departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Other charter", contracting_supplier_id: @supplier.id }
    ).call.record
    SaveTransportationSegment.new(
      agency: @agency, actor: @admin, departure: @departure, arrangement: other_arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Other segment", origin_name: "Hotel", destination_name: "Port",
        starts_on: "2027-11-06", ends_on: "2027-11-06", starts_at_local: "10:00", time_zone: "America/New_York",
        maximum_occupancy: 15, confirmed_motorcoaches: 1, additional_motorcoaches: 2,
        rate_amount: "100", final_count_on: "2027-11-03"
      }
    ).call
    other_pool = other_arrangement.versions.find_by!(status: "draft").capacity_pool_definitions.sole.capacity_pool

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierCostComponent.transaction(requires_new: true) do
        component.update_columns(quantity_capacity_pool_id: other_pool.id)
      end
    end

    component.quantity_capacity_pool = component_for(draft, port).quantity_capacity_pool
    assert_not component.valid?
    assert_includes component.errors[:quantity_capacity_pool], "must belong to this segment"
  end

  test "an amount-due contributor cannot use another version's definition or component" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    confirm!
    activate!
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    contributor = successor.supplier_amount_due_contributors.order(:position).first
    predecessor_component = component_for(@arrangement.governing_version, hotel)
    predecessor_definition = @arrangement.governing_version.supplier_amount_due_definitions.sole

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierAmountDueContributor.transaction(requires_new: true) do
        SupplierAmountDueContributor.insert!(contributor_row(contributor, supplier_cost_component_id: predecessor_component.id, position: 9))
      end
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierAmountDueContributor.transaction(requires_new: true) do
        SupplierAmountDueContributor.insert!(contributor_row(contributor, supplier_amount_due_definition_id: predecessor_definition.id, position: 10))
      end
    end

    mismatched_component = successor.supplier_amount_due_contributors.build(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: successor,
      supplier_amount_due_definition: successor.supplier_amount_due_definitions.sole,
      supplier_cost_component: predecessor_component, position: 9
    )
    assert_not mismatched_component.valid?
    assert_includes mismatched_component.errors[:supplier_cost_component], "must belong to this exact version"

    mismatched_definition = successor.supplier_amount_due_contributors.build(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: successor,
      supplier_amount_due_definition: predecessor_definition,
      supplier_cost_component: component_for(successor, hotel), position: 9
    )
    assert_not mismatched_definition.valid?
    assert_includes mismatched_definition.errors[:supplier_amount_due_definition], "must belong to this exact version"
  end

  test "a successor keeps segment identities and a confirmed draft can be revised" do
    hotel = save_segment("Hotel → Port", date: "2027-11-06", time: "10:00", origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades", rate: "200", final_count: "2027-11-03")
    port = save_segment("Port → Airport", date: "2027-11-13", time: "09:30", origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport", rate: "175", final_count: "2027-11-10")
    SaveTransportationAmountDue.new(agency: @agency, actor: @admin, arrangement: @arrangement, due_on: "2027-11-03", idempotency_key: SecureRandom.uuid).call
    ActivateDeparture.new(agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.reload.lock_version).call
    confirm!
    revised = ReviseConfirmedSupplierArrangementVersion.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, reason: "Correct the pickup wording",
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: draft.lock_version,
      vertical: "ground_transportation"
    ).call.record
    assert_equal [ hotel.id, port.id ], revised.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: revised.id)

    confirm_version!(revised)
    activate_version!(revised)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal [ hotel.id, port.id ], successor.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
    assert_equal 20_000, @arrangement.governing_version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source).find_by!(supplier_cost_sources: { arrangement_item_id: hotel.id }).amount_minor_units
  end

  private

  def save_segment(name, date:, time:, origin:, destination:, rate:, final_count:, item: nil, confirmed: 1, ceiling: nil)
    SaveTransportationSegment.new(
      agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, item:,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name:, origin_name: origin, destination_name: destination,
        starts_on: date, ends_on: date, starts_at_local: time, time_zone: "America/New_York",
        maximum_occupancy: 15, confirmed_motorcoaches: confirmed, additional_motorcoaches: item ? nil : 2,
        maximum_total_resource_units: ceiling, rate_amount: rate, final_count_on: final_count
      }
    ).call
  end

  def draft
    @arrangement.versions.find_by!(status: "draft")
  end

  def confirm!(version = draft)
    confirm_version!(version)
  end

  def confirm_version!(version)
    RecordTransportationSupplierConfirmation.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version:,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current, channel: "email",
        reference_note: "ABC confirmed the charter", confirmed_without_identifier_reason: "No file number yet"
      }
    ).call
  end

  def activate!(version = @arrangement.versions.find_by!(status: "draft"))
    ActivateDeparture.new(agency: @agency, actor: @admin, departure: @departure, lock_version: @departure.reload.lock_version).call unless @departure.reload.active?
    activate_version!(version)
  end

  def activate_version!(version)
    ActivateTransportationAgreement.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, version:,
      idempotency_key: SecureRandom.uuid,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version
    ).call
  end

  def change!(item, event_type, effective_on, pool: nil)
    pool ||= @arrangement.reload.governing_version.capacity_pool_definitions.find_by!(arrangement_item: item).capacity_pool
    RecordTransportationCoachChange.new(
      agency: @agency, actor: @admin, arrangement: @arrangement, item:, quantity: 1,
      effective_on:, event_type:, idempotency_key: SecureRandom.uuid,
      projection_lock_version: pool.capacity_projection.reload.lock_version,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        evidence_reference_note: "ABC coach update"
      }
    ).call
  end

  def charter_today
    Time.current.in_time_zone("America/New_York").to_date
  end

  def forecast_total(version = draft)
    result = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version:
    ).call
    result.arrangements.sum { |arrangement| arrangement.totals.forecast_supplier_cost_minor_units.to_i }
  end

  def segment_exposure(version, item)
    result = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement, version:
    ).call
    source_ids = version.supplier_cost_sources.where(arrangement_item: item).pluck(:id)
    result.arrangements.flat_map(&:sources).select { |source| source_ids.include?(source.source_id) }.sum { |source| source.totals.forecast_supplier_cost_minor_units.to_i }
  end

  def amount_due(version)
    EvaluateSupplierAmountDue.new(version:).call
  end

  def compile(version)
    CompileTransportationAgreement.new(agency: @agency, departure: @departure, arrangement: @arrangement, version:).call
  end

  def other_item(item)
    @arrangement.arrangement_items.where.not(id: item.id).sole
  end

  def contributor_row(contributor, overrides)
    contributor.attributes.except("id").merge(overrides.stringify_keys).merge(
      "id" => SecureRandom.uuid,
      "created_at" => Time.current,
      "updated_at" => Time.current
    )
  end

  def component_for(version, item)
    version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { arrangement_item_id: item.id })
      .where.not(supplier_cost_sources: { label: "Extra coach charge" })
      .order("supplier_cost_sources.position")
      .first!
  end

  def add_second_source(item)
    occurrence = item.service_occurrences.sole
    resource = item.supplier_resources.sole
    CreateSupplierCostSetup.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: draft.lock_version,
      idempotency_key: SecureRandom.uuid,
      source_attributes: {
        charging_supplier_id: @supplier.id,
        label: "Extra coach charge",
        arrangement_item_id: item.id,
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id
      },
      definition_attributes: { stage: "contracted", mode: "calculated", currency: "USD" },
      component_attributes: {
        label: "Extra coach charge",
        economic_role: "supplier_charge",
        calculation_kind: "unit_rate",
        quantity_basis: "resource_units",
        amount_minor_units: 5_000,
        pass_through: false
      }
    ).call.record
  end

  def add_lodging_stay
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    version = draft
    version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Hilton stay", category: "lodging",
      capacity_management: "unmanaged", default_service_provider: @supplier, position: 3
    )
    occurrence = item.service_occurrences.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement, status: "planned"
    )
    definition = version.service_occurrence_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, service_occurrence: occurrence, name: "Hilton stay",
      starts_on: Date.new(2027, 11, 6), ends_on: Date.new(2027, 11, 13),
      starts_at_local: "15:00", ends_at_local: "11:00",
      time_zone: "America/New_York", service_provider: @supplier
    )
    { item:, occurrence_definition: definition }
  end
end
