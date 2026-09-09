require "test_helper"

class SupplierPlanningCommandsTest < ActiveSupport::TestCase
  setup do
    @departure = create_departure!(agencies(:one), actor: users(:one))
    @supplier = parties(:organization_one)
    assign_supplier_role!(@supplier, actor: users(:one)) unless @supplier.supplier_profile
  end

  test "staff with office access can create arrangement reservation resource and confirmation" do
    arrangement = create_arrangement!(actor: users(:staff_one))
    resource = CreateSupplierResource.new(
      agency: agencies(:one), actor: users(:staff_one), arrangement:, name: "Balcony", resource_kind: "cabin_category", capacity_unit: "cabin"
    ).call.supplier_resource
    reservation = CreateSupplierReservation.new(
      agency: agencies(:one), actor: users(:staff_one), arrangement:, name: "Cabin 101", resources: [ resource ]
    ).call.supplier_reservation
    confirmation = RecordSupplierConfirmation.new(
      agency: agencies(:one), actor: users(:staff_one), reservation:, issuer_party: @supplier, identifier_type: "supplier_confirmation", context: "portal", raw_value: "CONF-1"
    ).call.supplier_confirmation

    ConfirmSupplierReservation.new(agency: agencies(:one), actor: users(:staff_one), reservation:).call

    assert arrangement.draft?
    assert resource.active?
    assert reservation.reload.confirmed?
    assert confirmation.effective?
    assert_includes agencies(:one).audit_events.pluck(:action), "supplier_reservation.confirmed"
  end

  test "cross agency arrangement create is rejected" do
    error = assert_raises(MembershipCommand::Error) do
      CreateSupplierArrangement.new(
        agency: agencies(:one),
        actor: users(:one),
        departure: create_departure!(agencies(:two), actor: users(:two)),
        supplier_party: @supplier,
        name: "Forged"
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "reservation confirm requires identifier evidence or explicit reason" do
    arrangement = create_arrangement!
    reservation = CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement:, name: "Cabin 101").call.supplier_reservation

    error = assert_raises(MembershipCommand::Error) do
      ConfirmSupplierReservation.new(agency: agencies(:one), actor: users(:one), reservation:).call
    end
    assert_equal :confirmation_evidence_required, error.code

    ConfirmSupplierReservation.new(
      agency: agencies(:one), actor: users(:one), reservation:, without_identifier_reason: "Supplier confirmed by phone before issuing a reference"
    ).call
    assert reservation.reload.confirmed?
  end

  test "parent arrangement cancellation rejects nonterminal children and reservations" do
    parent = create_arrangement!(name: "Parent")
    create_arrangement!(name: "Child", parent_arrangement: parent)

    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:one), arrangement: parent, reason: "No longer needed").call
    end
    assert_equal :dependency, error.code

    leaf = create_arrangement!(name: "Reservation parent")
    CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement: leaf, name: "Cabin 101").call
    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:one), arrangement: leaf, reason: "No longer needed").call
    end
    assert_equal :dependency, error.code
  end

  test "staff cannot cancel an arrangement" do
    arrangement = create_arrangement!(actor: users(:staff_one))

    error = assert_raises(MembershipCommand::Error) do
      CancelSupplierArrangement.new(agency: agencies(:one), actor: users(:staff_one), arrangement:, reason: "No longer needed").call
    end
    assert_equal :unauthorized, error.code
  end

  test "resource deactivation rejects nonterminal reservation links" do
    arrangement = create_arrangement!
    resource = CreateSupplierResource.new(
      agency: agencies(:one), actor: users(:one), arrangement:, name: "Room", resource_kind: "room_type", capacity_unit: "room"
    ).call.supplier_resource
    CreateSupplierReservation.new(agency: agencies(:one), actor: users(:one), arrangement:, name: "Room request", resources: [ resource ]).call

    error = assert_raises(MembershipCommand::Error) do
      DeactivateSupplierResource.new(agency: agencies(:one), actor: users(:one), resource:, reason: "Closed").call
    end
    assert_equal :dependency, error.code
  end

  test "supplier planning blocks party deactivation with samples" do
    arrangement = create_arrangement!

    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(agency: agencies(:one), actor: users(:one), party: @supplier, reason: "Duplicate").call
    end
    assert_equal :party_dependency, error.code
    assert_match(/supplier arrangement/, error.message)
    assert_match(/#{arrangement.name}/, error.message)
  end

  test "transfer is frozen after first arrangement and rejected transfer writes no success audit" do
    target = CreateOffice.new(agency: agencies(:one), actor: users(:one), name: "Transfer Target", code: "T#{SecureRandom.hex(4).upcase[0, 8]}", default_timezone: agencies(:one).default_timezone).call.office
    GrantOfficeAccess.new(agency: agencies(:one), actor: users(:one), membership: agency_memberships(:one), office: target).call
    create_arrangement!
    before = agencies(:one).audit_events.where(action: "departure.office_transferred").count

    error = assert_raises(MembershipCommand::Error) do
      TransferDepartureOffice.new(agency: agencies(:one), actor: users(:one), departure: @departure, office: target).call
    end

    assert_equal :office_transfer_frozen, error.code
    assert_equal before, agencies(:one).audit_events.where(action: "departure.office_transferred").count
  end

  test "Napa fixed coach term is expressible as estimate then contracted" do
    @departure = napa_wine_country_departure!(actor: users(:one))
    arrangement = create_arrangement!(name: "Coach Contract")
    estimate = create_fixed_term!(arrangement:, basis: "estimate", amount_minor_units: 250_000, cost_category: "coach")
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: estimate).call

    contracted = create_fixed_term!(arrangement:, basis: "contracted", amount_minor_units: 275_000, cost_category: "coach")
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: contracted).call

    assert_equal 250_000, SupplierCostTermEvaluation.evaluate(estimate).amount_minor_units
    controlling = SupplierEconomicItemPrecedence.controlling_for(agency: agencies(:one), economic_item_key: contracted.economic_item_key)
    assert_equal "contracted", controlling.stage
    assert_equal 275_000, controlling.valuation.amount_minor_units
  end

  test "Smith minimum guarantee term is expressible as estimate then contracted" do
    @departure = smith_family_reunion_departure!(actor: users(:one))
    arrangement = create_arrangement!(name: "Cruise Guarantee")
    estimate = create_minimum_guarantee_term!(arrangement:, basis: "estimate", minimum_quantity: 10, unit_amount_minor_units: 150_000)
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: estimate).call
    contracted = create_minimum_guarantee_term!(arrangement:, basis: "contracted", minimum_quantity: 12, unit_amount_minor_units: 150_000)
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: contracted).call

    assert_equal 1_500_000, SupplierCostTermEvaluation.evaluate(estimate).amount_minor_units
    assert_equal 1_800_000, SupplierCostTermEvaluation.evaluate(contracted).amount_minor_units
  end

  test "deposit deadlines are linked and completion does not mark deposit paid" do
    arrangement = create_arrangement!
    deposit = CreateSupplierDepositRequirement.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      arrangement:,
      name: "Initial deposit",
      amount_minor_units: 50_000,
      due_rule: "Due 30 days after contract signature",
      due_on: Date.new(2027, 1, 15),
      trigger_condition: "Contract signed",
      provenance: "Supplier contract draft"
    ).call.supplier_deposit_requirement
    deadline = CreateSupplierDeadline.new(agency: agencies(:one), actor: users(:staff_one), deposit_requirement: deposit).call.supplier_deadline

    CompleteSupplierDeadline.new(agency: agencies(:one), actor: users(:staff_one), deadline:, reason: "Task completed outside supplier payment records").call

    assert_equal deposit.id, deadline.reload.source_deposit_requirement_id
    assert deadline.completed?
    assert_not deposit.reload.attributes.key?("paid")
    assert_equal "active", deposit.status
  end

  test "precedence never sums estimate contracted and commitment stages" do
    arrangement = create_arrangement!
    estimate = create_fixed_term!(arrangement:, basis: "estimate", amount_minor_units: 100_000, cost_category: "coach")
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: estimate).call
    contracted = create_fixed_term!(arrangement:, basis: "contracted", amount_minor_units: 125_000, cost_category: "coach")
    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term: contracted).call
    commitment = CreateSupplierCommitment.new(agency: agencies(:one), actor: users(:one), governing_term: contracted, reason: "Supplier guarantee accepted").call.supplier_commitment

    controlling = SupplierEconomicItemPrecedence.controlling_for(agency: agencies(:one), economic_item_key: estimate.economic_item_key)

    assert_equal "commitment", controlling.stage
    assert_equal commitment.id, controlling.record.id
    assert_equal 125_000, controlling.valuation.amount_minor_units
  end

  test "staff can draft terms but cannot activate contracted terms or create commitments" do
    arrangement = create_arrangement!(actor: users(:staff_one))
    term = create_fixed_term!(arrangement:, actor: users(:staff_one), basis: "contracted")
    assert term.draft?

    error = assert_raises(MembershipCommand::Error) do
      ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:staff_one), term:).call
    end
    assert_equal :unauthorized, error.code

    ActivateSupplierCostTerm.new(agency: agencies(:one), actor: users(:one), term:).call
    error = assert_raises(MembershipCommand::Error) do
      CreateSupplierCommitment.new(agency: agencies(:one), actor: users(:staff_one), governing_term: term.reload, reason: "Staff attempt").call
    end
    assert_equal :unauthorized, error.code
  end

  test "cross agency term activation is rejected without success audit" do
    arrangement = create_arrangement!
    term = create_fixed_term!(arrangement:)
    before = agencies(:one).audit_events.where(action: "supplier_cost_term.activated").count

    error = assert_raises(MembershipCommand::Error) do
      ActivateSupplierCostTerm.new(agency: agencies(:two), actor: users(:two), term:).call
    end

    assert_equal :invalid, error.code
    assert_equal before, agencies(:one).audit_events.where(action: "supplier_cost_term.activated").count
  end

  private

  def create_arrangement!(name: "Cruise Block", parent_arrangement: nil, actor: users(:one))
    CreateSupplierArrangement.new(
      agency: agencies(:one),
      actor:,
      departure: @departure,
      supplier_party: @supplier,
      parent_arrangement:,
      name:
    ).call.supplier_arrangement
  end

  def create_fixed_term!(arrangement:, actor: users(:one), basis: "estimate", amount_minor_units: 100_000, cost_category: "lodging")
    CreateSupplierCostTerm.new(
      agency: agencies(:one),
      actor:,
      arrangement:,
      shape: "fixed",
      basis:,
      cost_category:,
      quantity_basis: "arrangement",
      quantity_unit: "contract",
      detail_attributes: { amount_minor_units: },
      provenance: "Supplier worksheet"
    ).call.supplier_cost_term
  end

  def create_minimum_guarantee_term!(arrangement:, basis:, minimum_quantity:, unit_amount_minor_units:)
    CreateSupplierCostTerm.new(
      agency: agencies(:one),
      actor: users(:one),
      arrangement:,
      shape: "minimum_guarantee",
      basis:,
      cost_category: "cabin_guarantee",
      quantity_basis: "guaranteed_quantity",
      quantity_unit: "cabin",
      detail_attributes: { minimum_quantity:, unit_amount_minor_units: },
      provenance: "Supplier guarantee schedule"
    ).call.supplier_cost_term
  end
end
