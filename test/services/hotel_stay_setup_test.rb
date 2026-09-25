# frozen_string_literal: true

require "test_helper"

class HotelStaySetupTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Hilton stay")
    @contractor = create_capacity_supplier(@agency, "Hilton")
  end

  test "hilton facts compile without a room category, pool, or client price" do
    setup = create_stay
    arrangement = setup.record.arrangement
    version = arrangement.versions.sole
    item = setup.record.item

    record_cost(arrangement, version, item, "Additional adult", "20.00", "per_person_night")
    record_cost(arrangement, version, item, "Tax", "3.20", "per_person_night")
    record_milestone(arrangement, version, item, "option_date", "2027-02-04")
    record_milestone(arrangement, version, item, "rooming_list", "2027-10-18")
    record_milestone(arrangement, version, item, "final_payment", "2027-02-04")
    version.reload
    RecordHotelDeposit.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, percentage: "15", date: "2027-02-04",
        description: "15% deposit on guaranteed rooms", version_lock_version: version.lock_version
      }
    ).call
    offer = ConnectHotelServiceOffer.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Hilton stay", arrangement_item_id: item.id,
        arrangement_lock_version: version.reload.lock_version
      }
    ).call.record

    occurrence = arrangement.versions.sole.service_occurrence_definitions.sole
    assert_equal Date.new(2027, 11, 2), occurrence.starts_on
    assert_equal Date.new(2027, 11, 5), occurrence.ends_on
    assert_equal "America/New_York", occurrence.time_zone
    assert_equal [ 2_000, 320 ], cost_amounts(version, item)
    assert_equal "2027-02-04", version.supplier_deadline_definitions.find_by!(deadline_type: "option_or_release_date").rule_parameters["date"]
    assert_equal "2027-10-18", version.supplier_deadline_definitions.find_by!(deadline_type: "rooming_list_due").rule_parameters["date"]
    assert_equal "2027-02-04", version.supplier_deadline_definitions.find_by!(description: "Final payment").rule_parameters["date"]
    assert_equal BigDecimal("15"), version.supplier_deposit_requirement_definitions.sole.percentage
    assert_empty item.supplier_resources
    assert_empty version.capacity_pool_definitions
    assert_empty offer.editable_draft_version.price_components
    assert_equal item.id, offer.intended_arrangement_item_id
    assert AuditEvent.exists?(subject_id: arrangement.id, action: "supplier_arrangement.typed_item_setup")
  end

  test "replaying the stay key does not create a second arrangement" do
    key = SecureRandom.uuid
    first = create_stay(key)
    second = create_stay(key)
    assert_equal :replayed, second.status
    assert_equal first.record.arrangement.id, second.record.arrangement.id
    assert_equal 1, SupplierArrangement.where(departure: @departure, name: "Hilton Waikiki").count
  end

  test "a stale lock rejects the cost and leaves the stay unchanged" do
    setup = create_stay
    arrangement = setup.record.arrangement
    version = arrangement.versions.sole
    error = assert_raises(AgencyCommand::Error) do
      record_cost(arrangement, version, setup.record.item, "Additional adult", "20.00", "per_person_night", lock: version.lock_version + 1)
    end
    assert_equal :conflict, error.code
    assert_empty version.supplier_cost_sources
  end

  test "another agency's departure is not found" do
    other = create_capacity_departure(agencies(:cove), name: "Other Hilton")
    assert_raises(ActiveRecord::RecordNotFound) do
      CreateHotelStaySetup.new(
        agency: @agency, actor: @actor, departure: other, idempotency_key: SecureRandom.uuid,
        arrangement_attributes: { name: "Hilton Waikiki", contracting_supplier_id: @contractor.id },
        item_attributes: { name: "Hilton Waikiki" },
        occurrence_attributes: { name: "Stay", starts_on: "2027-11-02", ends_on: "2027-11-05", time_zone: "America/New_York" }
      ).call
    end
  end

  test "a governing version cannot take a new hotel cost" do
    setup = create_stay
    version = setup.record.arrangement.versions.sole
    version.update!(status: "activated", activated_at: Time.current)
    error = assert_raises(AgencyCommand::Error) do
      record_cost(setup.record.arrangement, version, setup.record.item, "Tax", "3.20", "per_person_night", lock: version.lock_version)
    end
    assert_equal :invalid_state, error.code
  end

  test "a cruise arrangement is not rewritten by a hotel cost" do
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: SecureRandom.uuid,
      arrangement_attributes: { name: "Celebrity", contracting_supplier_id: @contractor.id },
      item_attributes: { name: "Beyond" },
      occurrence_attributes: { name: "Sailing", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York" }
    ).call
    arrangement = sailing.record.arrangement
    shape = DetectHotelStayShape.new(agency: @agency, arrangement: arrangement).call
    assert_not shape.compatible?
    assert_raises(AgencyCommand::Error) do
      record_cost(arrangement, arrangement.versions.sole, sailing.record.item, "Tax", "3.20", "per_person_night")
    end
    assert_equal "cruise", arrangement.versions.sole.arrangement_item_definitions.sole.category
  end

  private

  def create_stay(key = SecureRandom.uuid)
    CreateHotelStaySetup.new(
      agency: @agency, actor: @actor, departure: @departure, idempotency_key: key,
      arrangement_attributes: { name: "Hilton Waikiki", contracting_supplier_id: @contractor.id },
      item_attributes: { name: "Hilton Waikiki" },
      occurrence_attributes: { name: "Stay", starts_on: "2027-11-02", ends_on: "2027-11-05", time_zone: "America/New_York" }
    ).call
  end

  def record_cost(arrangement, version, item, label, amount, shape, lock: nil)
    RecordHotelSupplierComponent.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, label: label, amount: amount, shape: shape,
        version_lock_version: lock || version.reload.lock_version
      }
    ).call
  end

  def record_milestone(arrangement, version, item, template, date)
    RecordHotelMilestone.new(
      agency: @agency, actor: @actor, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id, template: template, date: date,
        version_lock_version: version.reload.lock_version
      }
    ).call
  end

  def cost_amounts(version, item)
    SupplierCostComponent.joins(supplier_cost_definition: :supplier_cost_source)
      .where(supplier_cost_sources: { supplier_arrangement_version_id: version.id, arrangement_item_id: item.id })
      .order(:label)
      .pluck(:amount_minor_units)
  end
end
