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

  test "capacity transition matrix reconstructs hotel night position from events" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:, name: "Hotel Rooms", resource_kind: "room_type", capacity_unit: "room")
    occurrence = create_occurrence!(resource:, occurrence_kind: "night_slice", service_date: Date.new(2027, 7, 12))
    reservation = CreateSupplierReservation.new(agency: agencies(:one), actor: users(:staff_one), arrangement:, name: "Room reservation", resources: [ resource ]).call.supplier_reservation

    HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 10, guaranteed_quantity: 4, reason: "Initial room block", idempotency_key: SecureRandom.uuid).call
    RequestSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 5, reason: "Extension request", idempotency_key: SecureRandom.uuid).call
    ConfirmSupplierCapacityRequest.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 3, guaranteed_quantity: 2, reason: "Supplier confirmed extension", idempotency_key: SecureRandom.uuid).call
    IncreaseSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 4, guaranteed_quantity: 1, reason: "Added rooms", idempotency_key: SecureRandom.uuid).call
    ConsumeSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, reservation:, quantity: 6, reason: "Reservation consumes rooms", idempotency_key: SecureRandom.uuid).call
    RestoreSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, reservation:, quantity: 2, reason: "Room restored", idempotency_key: SecureRandom.uuid).call
    ReleaseSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 5, guaranteed_quantity: 2, reason: "Released unused rooms", idempotency_key: SecureRandom.uuid).call
    ReinstateSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 2, guaranteed_quantity: 1, reason: "Supplier approved reinstatement", idempotency_key: SecureRandom.uuid, supplier_approval_reference: "EMAIL-123", supplier_approval_received_at: Time.current).call
    ReduceSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 3, guaranteed_quantity: 1, reason: "Reduced block", idempotency_key: SecureRandom.uuid).call
    ExpireSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 3, held_quantity: 1, pending_quantity: 2, guaranteed_quantity: 1, reason: "Cutoff expired", idempotency_key: SecureRandom.uuid).call
    CorrectSupplierCapacity.new(agency: agencies(:one), actor: users(:one), resource:, service_occurrence: occurrence, pending_request_delta: 1, released_current_delta: -1, reason: "Correct supplier worksheet", idempotency_key: SecureRandom.uuid).call

    position = SupplierCapacityPosition.find_by!(resource:, service_occurrence: occurrence)
    assert_equal 10, position.agency_held
    assert_equal 1, position.pending_request
    assert_equal 4, position.guaranteed
    assert_equal 4, position.consumed
    assert_equal 3, position.released_current
    assert_equal 6, position.available
    assert_equal 5, position.released_cumulative

    rebuilt = position.supplier_capacity_events.order(:commanded_at, :id).each_with_object(SupplierCapacityPosition::BUCKETS.index_with(0)) do |event, buckets|
      SupplierCapacityPosition::BUCKETS.each { |bucket| buckets[bucket] += event.public_send("#{bucket}_delta") }
    end
    assert_equal position.attributes.slice(*SupplierCapacityPosition::BUCKETS), rebuilt
  end

  test "capacity supports coach seats without supplier reported total affecting availability" do
    arrangement = create_arrangement!(name: "Coach Contract")
    resource = create_resource!(arrangement:, name: "Motorcoach", resource_kind: "coach", capacity_unit: "seat")
    occurrence = create_occurrence!(resource:, occurrence_kind: "typed_segment", segment_type: "transfer", segment_identifier: "OUTBOUND")

    HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 30, reason: "Coach seat block", idempotency_key: SecureRandom.uuid).call
    position = SupplierCapacityPosition.find_by!(resource:, service_occurrence: occurrence)
    position.update!(supplier_reported_total: 56)

    assert_equal 30, position.available
    assert_equal 56, position.supplier_reported_total
  end

  test "capacity commands are idempotent and reject conflicting reuse" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    key = SecureRandom.uuid

    first = HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 3, reason: "Initial hold", idempotency_key: key).call
    replay = HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 3, reason: "Initial hold", idempotency_key: key).call

    assert_equal first.supplier_capacity_event.id, replay.supplier_capacity_event.id
    assert_equal 1, SupplierCapacityEvent.where(idempotency_key: key).count
    assert_equal 3, first.supplier_capacity_position.reload.agency_held

    error = assert_raises(MembershipCommand::Error) do
      HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 4, reason: "Different hold", idempotency_key: key).call
    end
    assert_equal :idempotency_conflict, error.code
  end

  test "missing position fails closed for noninitial mutations" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)

    error = assert_raises(MembershipCommand::Error) do
      IncreaseSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "Increase without projection", idempotency_key: SecureRandom.uuid).call
    end
    assert_equal :capacity_position_missing, error.code
  end

  test "consume requires a reservation using the resource" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 2, reason: "Initial hold", idempotency_key: SecureRandom.uuid).call

    error = assert_raises(MembershipCommand::Error) do
      ConsumeSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "No reservation", idempotency_key: SecureRandom.uuid).call
    end
    assert_equal :reservation_required, error.code
  end

  test "reinstate requires supplier-approved provenance" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 2, reason: "Initial hold", idempotency_key: SecureRandom.uuid).call
    ReleaseSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "Release", idempotency_key: SecureRandom.uuid).call

    error = assert_raises(MembershipCommand::Error) do
      ReinstateSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "Reinstate", idempotency_key: SecureRandom.uuid).call
    end
    assert_equal :supplier_approval_required, error.code
  end

  test "reconcile rebuilds projection without rewriting events and audits repair" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 5, reason: "Initial hold", idempotency_key: SecureRandom.uuid).call
    position = SupplierCapacityPosition.find_by!(resource:, service_occurrence: occurrence)
    event_count = position.supplier_capacity_events.count
    audit_count = agencies(:one).audit_events.where(action: "supplier_capacity_position.reconciled").count
    position.update_columns(agency_held: 3, updated_at: Time.current)

    ReconcileCapacityPosition.new(agency: agencies(:one), actor: users(:one), position:, reason: "Repair projection from event log").call

    assert_equal 5, position.reload.agency_held
    assert_equal event_count, position.supplier_capacity_events.count
    assert_equal audit_count + 1, agencies(:one).audit_events.where(action: "supplier_capacity_position.reconciled").count
  end

  test "capacity expected failures write no repair audit" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    before = agencies(:one).audit_events.where(action: "supplier_capacity_position.reconciled").count

    assert_raises(MembershipCommand::Error) do
      IncreaseSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "Missing projection", idempotency_key: SecureRandom.uuid).call
    end

    assert_equal before, agencies(:one).audit_events.where(action: "supplier_capacity_position.reconciled").count
  end

  test "capacity rejects cross agency mutation" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)

    error = assert_raises(MembershipCommand::Error) do
      HoldSupplierCapacity.new(agency: agencies(:two), actor: users(:two), resource:, service_occurrence: occurrence, quantity: 1, reason: "Forged hold", idempotency_key: SecureRandom.uuid).call
    end
    assert_equal :invalid, error.code
  end

  test "capacity events are append only and active positions block resource deactivation" do
    arrangement = create_arrangement!
    resource = create_resource!(arrangement:)
    occurrence = create_occurrence!(resource:)
    event = HoldSupplierCapacity.new(agency: agencies(:one), actor: users(:staff_one), resource:, service_occurrence: occurrence, quantity: 1, reason: "Initial hold", idempotency_key: SecureRandom.uuid).call.supplier_capacity_event

    assert_raises(ActiveRecord::ReadonlyAttributeError) { event.update!(reason: "mutated") }
    assert_not event.destroy

    error = assert_raises(MembershipCommand::Error) do
      DeactivateSupplierResource.new(agency: agencies(:one), actor: users(:one), resource:, reason: "Closed").call
    end
    assert_equal :dependency, error.code
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

  def create_resource!(arrangement:, actor: users(:staff_one), name: "Cabin Category", resource_kind: "cabin_category", capacity_unit: "cabin")
    CreateSupplierResource.new(
      agency: agencies(:one),
      actor:,
      arrangement:,
      name:,
      resource_kind:,
      capacity_unit:
    ).call.supplier_resource
  end

  def create_occurrence!(resource:, actor: users(:staff_one), occurrence_kind: "typed_segment", service_date: nil, segment_type: "sailing", segment_identifier: "MAIN")
    CreateSupplierServiceOccurrence.new(
      agency: agencies(:one),
      actor:,
      resource:,
      occurrence_kind:,
      service_date:,
      segment_type: occurrence_kind == "typed_segment" ? segment_type : nil,
      segment_identifier: occurrence_kind == "typed_segment" ? segment_identifier : nil
    ).call.supplier_service_occurrence
  end
end
