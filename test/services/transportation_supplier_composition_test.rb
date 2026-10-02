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

    change!(hotel, "increased", Date.current)
    version = @arrangement.reload.governing_version
    assert_equal 40_000, segment_exposure(version, hotel)
    assert_equal 17_500, segment_exposure(version, other_item(hotel))
    assert_equal 57_500, forecast_total(version)
    assert_equal 57_500, amount_due(version).total_minor_units
    assert_equal [ 40_000, 17_500 ], amount_due(version).lines.map(&:amount_minor_units)

    travel_to(Date.current + 2) do
      change!(hotel, "increased", Date.current + 30)
      assert_equal 57_500, forecast_total(@arrangement.reload.governing_version)
      assert_equal 77_500, amount_due(@arrangement.reload.governing_version).total_minor_units
    end

    change!(hotel, "released", Date.current)
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
    change!(hotel, "increased", Date.current)
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
end
