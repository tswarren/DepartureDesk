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

  test "cost term basis excludes committed stage at the database" do
    arrangement = create_arrangement!
    row = cost_term_row(arrangement:)

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostTerm.transaction(requires_new: true) do
        SupplierCostTerm.insert_all!([ row.merge(basis: "committed") ])
      end
    end
  end

  test "per person details require explicit planning or guaranteed quantity" do
    term = create_cost_term!(shape: "per_person", detail_attributes: { unit_amount_minor_units: 10_000, planning_person_quantity: 20 })
    assert_equal 200_000, SupplierCostTermEvaluation.evaluate(term).amount_minor_units

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostTermPerPersonDetail.transaction(requires_new: true) do
        SupplierCostTermPerPersonDetail.insert_all!([ detail_row(term:, unit_amount_minor_units: 10_000) ])
      end
    end
  end

  test "advanced cost term detail constraints reject invalid rows" do
    term = create_draft_cost_term!(shape: "tiered", detail_attributes: { tiers: [ { threshold_quantity: 1, unit_amount_minor_units: 10_000 } ] }, evaluation_inputs: { "qualifying_quantity" => 1 })

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierCostTermTier.transaction(requires_new: true) do
        SupplierCostTermTier.insert_all!([ advanced_tier_row(term:).merge(agency_id: agencies(:two).id) ])
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostTermTier.transaction(requires_new: true) do
        SupplierCostTermTier.insert_all!([ advanced_tier_row(term:, threshold_quantity: 2, unit_amount_minor_units: -1) ])
      end
    end
  end

  test "stepped detail bands cannot overlap" do
    term = create_draft_cost_term!(
      shape: "stepped",
      detail_attributes: {
        steps: [
          { band_start_quantity: 1, band_end_quantity: 10, unit_amount_minor_units: 10_000 }
        ]
      },
      evaluation_inputs: { "qualifying_quantity" => 10 }
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostTermStep.transaction(requires_new: true) do
        SupplierCostTermStep.insert_all!([ advanced_step_row(term:, band_start_quantity: 10, band_end_quantity: 20) ])
      end
    end
  end

  test "deadline must reference a deposit requirement source in this slice" do
    arrangement = create_arrangement!
    now = Time.current

    assert_raises(ActiveRecord::NotNullViolation) do
      SupplierDeadline.transaction(requires_new: true) do
        SupplierDeadline.insert_all!([ {
          id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
          agency_id: agencies(:one).id,
          office_id: arrangement.office_id,
          departure_id: arrangement.departure_id,
          arrangement_id: arrangement.id,
          source_deposit_requirement_id: nil,
          name: "Deposit deadline",
          original_due_on: Date.new(2027, 1, 15),
          due_on: Date.new(2027, 1, 15),
          status: "open",
          created_by_membership_id: agency_memberships(:one).id,
          status_changed_at: now,
          status_changed_by_membership_id: agency_memberships(:one).id,
          lock_version: 0,
          created_at: now,
          updated_at: now
        } ])
      end
    end
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

  def create_cost_term!(shape:, detail_attributes:)
    term = create_draft_cost_term!(shape:, detail_attributes:)
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term:).call
    term.reload
  end

  def create_draft_cost_term!(shape:, detail_attributes:, evaluation_inputs: {})
    arrangement = create_arrangement!
    CreateSupplierCostTerm.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      shape:,
      basis: "estimate",
      cost_category: "lodging",
      quantity_basis: "planning_quantity",
      quantity_unit: "person",
      detail_attributes:,
      evaluation_inputs:,
      provenance: "Supplier worksheet"
    ).call.supplier_cost_term
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

  def cost_term_row(arrangement:)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: agencies(:one).id,
      office_id: arrangement.office_id,
      departure_id: arrangement.departure_id,
      arrangement_id: arrangement.id,
      economic_item_id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      economic_item_key: "arrangement:#{arrangement.id}|category:test|basis:planning|unit:item|currency:USD",
      cost_category: "test",
      quantity_basis: "planning",
      quantity_unit: "item",
      shape: "fixed",
      basis: "estimate",
      status: "draft",
      currency: "USD",
      term_version: 1,
      rounding_method: "nearest_minor_unit",
      tax_fee_treatment: "excluded",
      provenance: "Supplier worksheet",
      created_by_membership_id: agency_memberships(:one).id,
      status_changed_at: now,
      status_changed_by_membership_id: agency_memberships(:one).id,
      lock_version: 0,
      created_at: now,
      updated_at: now
    }
  end

  def detail_row(term:, unit_amount_minor_units:)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: term.agency_id,
      supplier_cost_term_id: term.id,
      unit_amount_minor_units:,
      created_at: now,
      updated_at: now
    }
  end

  def advanced_tier_row(term:, threshold_quantity: 2, unit_amount_minor_units: 10_000)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: term.agency_id,
      supplier_cost_term_id: term.id,
      threshold_quantity:,
      unit_amount_minor_units:,
      created_at: now,
      updated_at: now
    }
  end

  def advanced_step_row(term:, band_start_quantity:, band_end_quantity:, unit_amount_minor_units: 10_000)
    now = Time.current
    {
      id: SecureRandom.uuid_v7(extra_timestamp_bits: 12),
      agency_id: term.agency_id,
      supplier_cost_term_id: term.id,
      band_start_quantity:,
      band_end_quantity:,
      unit_amount_minor_units:,
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
