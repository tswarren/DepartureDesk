# frozen_string_literal: true

require "test_helper"

class Slice3FamilyAdaptersTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith shore")
    @contractor = create_capacity_supplier(@agency, "Smith transfers")
  end

  test "three smith transfers save independently and do not store client prices" do
    hotel = segment("Hotel to Port", "Hotel", "Port", "200.00")
    airport = segment("Airport to Port", "Airport", "Port", "175.00", arrangement: hotel.record.arrangement)
    returning = segment("Port to Airport", "Port", "Airport", "175.00", arrangement: hotel.record.arrangement)
    arrangement = hotel.record.arrangement

    update_cost(arrangement, hotel.record.item, "Hotel to Port", "210.00")

    assert_equal 21_000, amount_for(arrangement, hotel.record.item)
    assert_equal 17_500, amount_for(arrangement, airport.record.item)
    assert_equal 17_500, amount_for(arrangement, returning.record.item)
    assert_equal 15, arrangement.versions.sole.supplier_resource_definitions.find_by!(supplier_resource_id: hotel.record.resource.id).maximum_occupancy
    assert_empty arrangement.versions.sole.capacity_pool_definitions
    [ hotel, airport, returning ].each do |saved|
      offer = connect_transport(arrangement, saved.record.item, saved.record.item.id)
      assert_empty offer.editable_draft_version.price_components
    end
    assert_equal 3, arrangement.arrangement_items.count
  end

  test "island sightseeing stores the supplier minimum and leaves the client price unsaved" do
    offering = CreateActivityOffering.new(
      agency: @agency, actor: @actor, departure: @departure, template: "activity",
      idempotency_key: SecureRandom.uuid,
      arrangement_attributes: { name: "Island Sightseeing", contracting_supplier_id: @contractor.id },
      item_attributes: { name: "Island Sightseeing" },
      occurrence_attributes: { name: "Island Sightseeing", starts_on: "2027-10-08", ends_on: "2027-10-08", time_zone: "America/New_York" }
    ).call
    arrangement = offering.record.arrangement
    item = offering.record.item
    version = arrangement.versions.sole
    RecordActivitySupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, label: "Sightseeing", amount: "50.00", shape: "per_person",
        minimum_quantity: 5, version_lock_version: version.lock_version
      }
    ).call
    RecordActivityMilestone.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, template: "option_date", date: "2027-09-24",
        version_lock_version: version.reload.lock_version
      }
    ).call
    offer = ConnectActivityServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: { mode: "new", title: "Island Sightseeing", arrangement_item_id: item.id, arrangement_lock_version: version.reload.lock_version }
    ).call.record

    assert_equal Date.new(2027, 10, 8), version.service_occurrence_definitions.sole.starts_on
    assert_equal 5_000, amount_for(arrangement, item)
    assert_equal 5, SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(calculation_kind: "minimum_quantity_shortfall").sole.minimum_quantity
    assert_equal "2027-09-24", version.supplier_deadline_definitions.sole.rule_parameters["date"]
    assert_empty version.capacity_pool_definitions
    assert_empty offer.editable_draft_version.price_components
  end

  test "a failed activity row leaves the transportation sibling unchanged" do
    transfer = segment("Hotel to Port", "Hotel", "Port", "200.00")
    arrangement = transfer.record.arrangement
    activity = CreateActivityOffering.new(
      agency: @agency, actor: @actor, departure: @departure, template: "meal", arrangement: arrangement,
      version_lock_version: arrangement.versions.sole.lock_version, idempotency_key: SecureRandom.uuid,
      arrangement_attributes: {}, item_attributes: { name: "Welcome dinner" },
      occurrence_attributes: { name: "Dinner", starts_on: "2027-10-08", ends_on: "2027-10-08", time_zone: "America/New_York" }
    ).call
    assert_raises(AgencyCommand::Error) do
      RecordActivitySupplierComponent.new(
        agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
        attributes: {
          arrangement_item_id: activity.record.item.id, label: "Dinner", amount: "", shape: "per_person",
          version_lock_version: arrangement.versions.sole.reload.lock_version
        }
      ).call
    end
    assert_equal 20_000, amount_for(arrangement, transfer.record.item)
    rows = CompileDmcItemTable.new(agency: @agency, arrangement: arrangement).call
    assert_equal [ "Transportation", "Meal" ], rows.map { |row| row[:family] }
    assert_equal 20_000, rows.first[:supplier_cost]
  end

  private

  def segment(name, pickup, dropoff, amount, arrangement: nil)
    saved = CreateTransportationSegment.new(
      agency: @agency, actor: @actor, departure: @departure, arrangement: arrangement,
      version_lock_version: arrangement&.versions&.sole&.lock_version,
      idempotency_key: SecureRandom.uuid, seat_count: 15,
      arrangement_attributes: { name: "Smith transfers", contracting_supplier_id: @contractor.id },
      item_attributes: { name: name },
      occurrence_attributes: {
        name: name, pickup: pickup, dropoff: dropoff, starts_on: "2027-11-06", ends_on: "2027-11-06",
        time_zone: "America/New_York"
      }
    ).call
    host = saved.record.arrangement
    RecordTransportationSupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: host, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: saved.record.item.id, label: name, amount: amount, shape: "per_segment",
        version_lock_version: host.versions.sole.reload.lock_version
      }
    ).call
    saved
  end

  def update_cost(arrangement, item, label, amount)
    RecordTransportationSupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, label: label, amount: amount,
        shape: "per_segment", version_lock_version: arrangement.versions.sole.reload.lock_version
      }
    ).call
  end

  def connect_transport(arrangement, item, title)
    ConnectTransportationServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: title, arrangement_item_id: item.id,
        arrangement_lock_version: arrangement.versions.sole.reload.lock_version
      }
    ).call.record
  end

  def amount_for(arrangement, item)
    SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { arrangement_item_id: item.id })
      .where.not(calculation_kind: "minimum_quantity_shortfall")
      .sole.amount_minor_units
  end
end
