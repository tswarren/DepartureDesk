require "test_helper"

class SupplierPlanningTest < ActiveSupport::TestCase
  setup do
    @departure = create_departure!(agencies(:one), actor: users(:one))
    @supplier = parties(:organization_one)
    assign_supplier_role!(@supplier, actor: users(:one)) unless @supplier.supplier_profile
  end

  test "arrangement status is database constrained" do
    row = arrangement_row

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangement.transaction(requires_new: true) do
        SupplierArrangement.insert_all!([ row.merge(status: "held") ])
      end
    end
  end

  test "arrangement departure office composite key rejects cross-office rows" do
    row = arrangement_row

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierArrangement.transaction(requires_new: true) do
        SupplierArrangement.insert_all!([ row.merge(office_id: offices(:two).id) ])
      end
    end
  end

  test "confirmation owner is exactly one arrangement or reservation" do
    arrangement = create_arrangement!
    row = confirmation_row(arrangement:)

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierConfirmation.transaction(requires_new: true) do
        SupplierConfirmation.insert_all!([ row.merge(arrangement_id: nil) ])
      end
    end

    reservation = create_reservation!(arrangement:)
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierConfirmation.transaction(requires_new: true) do
        SupplierConfirmation.insert_all!([ row.merge(reservation_id: reservation.id) ])
      end
    end
  end

  test "confirmation uniqueness is scoped to issuer type context and normalized value" do
    arrangement = create_arrangement!
    RecordSupplierConfirmation.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      issuer_party: @supplier,
      identifier_type: "group_contract",
      context: "supplier_portal",
      raw_value: "abc 123"
    ).call

    assert_raises(ActiveRecord::RecordNotUnique) do
      SupplierConfirmation.transaction(requires_new: true) do
        SupplierConfirmation.insert_all!([ confirmation_row(arrangement:).merge(normalized_value: "ABC 123") ])
      end
    end
  end

  test "service occurrence validates night slices and typed segments" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)

    night = CreateSupplierServiceOccurrence.new(
      agency: agencies(:one),
      actor: users(:one),
      resource:,
      occurrence_kind: "night_slice",
      service_date: Date.new(2027, 7, 12)
    ).call.supplier_service_occurrence
    assert night.night_slice?

    segment = CreateSupplierServiceOccurrence.new(
      agency: agencies(:one),
      actor: users(:one),
      resource:,
      occurrence_kind: "typed_segment",
      segment_type: "coach_leg",
      segment_identifier: "SFO-NAPA"
    ).call.supplier_service_occurrence
    assert segment.typed_segment?

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierServiceOccurrence.transaction(requires_new: true) do
        SupplierServiceOccurrence.insert_all!([ occurrence_row(resource:).merge(occurrence_kind: "night_slice", service_date: nil) ])
      end
    end
  end

  test "arrangement parent trigger rejects cycles" do
    parent = create_arrangement!(name: "Parent")
    child = create_arrangement!(name: "Child", parent_arrangement: parent)

    error = assert_raises(MembershipCommand::Error) do
      ReparentSupplierArrangement.new(
        agency: agencies(:one),
        actor: users(:one),
        arrangement: parent,
        parent_arrangement: child
      ).call
    end
    assert_equal :cycle, error.code
  end

  private

  def create_arrangement!(name: "Cruise Block", parent_arrangement: nil)
    CreateSupplierArrangement.new(
      agency: agencies(:one),
      actor: users(:one),
      departure: @departure,
      supplier_party: @supplier,
      parent_arrangement:,
      name:
    ).call.supplier_arrangement
  end

  def create_reservation!(arrangement:)
    CreateSupplierReservation.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      name: "Cabin request"
    ).call.supplier_reservation
  end

  def create_resource!(arrangement:)
    CreateSupplierResource.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      name: "Balcony cabin",
      resource_kind: "cabin_category",
      capacity_unit: "cabin"
    ).call.supplier_resource
  end

  def arrangement_row
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: agencies(:one).id,
      office_id: @departure.office_id,
      departure_id: @departure.id,
      supplier_party_id: @supplier.id,
      name: "Constraint block",
      status: "draft",
      supplier_display_name_snapshot: @supplier.display_name,
      created_by_membership_id: agency_memberships(:one).id,
      status_changed_at: now,
      status_changed_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def confirmation_row(arrangement:)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: agencies(:one).id,
      office_id: arrangement.office_id,
      departure_id: arrangement.departure_id,
      arrangement_id: arrangement.id,
      issuer_party_id: @supplier.id,
      issuer_display_name_snapshot: @supplier.display_name,
      identifier_type: "group_contract",
      context: "supplier_portal",
      raw_value: "ABC 123",
      normalized_value: "ABC 123",
      status: "effective",
      entered_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def occurrence_row(resource:)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: agencies(:one).id,
      office_id: resource.office_id,
      departure_id: resource.departure_id,
      arrangement_id: resource.arrangement_id,
      resource_id: resource.id,
      occurrence_kind: "night_slice",
      service_date: Date.new(2027, 7, 12),
      created_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end
end
