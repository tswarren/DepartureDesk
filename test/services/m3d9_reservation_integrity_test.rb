require "test_helper"

class M3d9ReservationIntegrityTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "M3D9 Supplier")
    @departure = create_capacity_departure(@agency, name: "M3D9 Departure")
  end

  test "confirmed quantity basis diverging from scope is invalid" do
    graph = build_unmanaged_activated_graph!("M3D9 BasisReject")
    reservation = create_and_request_reservation!(graph)
    occurrence_scope = reservation.revisions.sole.scopes.find_by!(target_kind: "occurrence")

    error = assert_raises(AgencyCommand::Error) do
      respond!(
        reservation,
        outcomes: {
          occurrence_scope.id => {
            outcome_kind: "confirmed",
            quantity: 4,
            quantity_basis: "resource_units"
          }
        }.merge(other_scopes_declined(reservation, except: occurrence_scope.id))
      )
    end
    assert_equal :invalid, error.code
    assert_match(/requested scope basis/i, error.message)
  end

  test "matching confirmed basis opens commitment with that basis not a silent relabel" do
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: "M3D9 BasisOpen", capacity_management: "unmanaged"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      trigger_kind: "reservation_confirmation",
      authority_shape: "confirmed_quantity",
      committed_supplier: @supplier,
      description: "Confirmed traveler positions",
      quantity_basis: "traveler_positions",
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      position: 1
    )
    activate_graph!(graph)
    reservation = create_and_request_reservation!(graph)
    occurrence_scope = reservation.revisions.sole.scopes.find_by!(target_kind: "occurrence")
    result = respond!(
      reservation,
      outcomes: {
        occurrence_scope.id => {
          outcome_kind: "confirmed",
          quantity: 4,
          quantity_basis: "traveler_positions"
        }
      }.merge(other_scopes_declined(reservation, except: occurrence_scope.id))
    )

    commitment = SupplierCommitment.find_by!(
      supplier_reservation_event_id: result.record.id
    )
    assert_equal "traveler_positions", commitment.quantity_basis
    assert_equal 4, commitment.quantity
    assert_includes commitment.calculation_snapshot, "basis=traveler_positions"
  end

  test "open commitment rejects confirmed basis that diverges from trigger" do
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: "M3D9 OpenReject", capacity_management: "unmanaged"
    )
    trigger = SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      trigger_kind: "reservation_confirmation",
      authority_shape: "confirmed_quantity",
      committed_supplier: @supplier,
      description: "Confirmed traveler positions",
      quantity_basis: "traveler_positions",
      position: 1
    )
    activate_graph!(graph)
    confirmation = SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version], confirming_supplier: @supplier,
      evidence_kind: "supplier_confirmation", evidence_on: Date.current,
      channel: "portal", reference_note: "Confirmed", actor: @actor, recorded_at: Time.current
    )

    error = assert_raises(AgencyCommand::Error) do
      OpenSupplierCommitmentAlreadyLocked.new(
        trigger: trigger,
        confirmation: confirmation,
        actor: @actor,
        confirmed_quantity: 3,
        confirmed_quantity_basis: "resource_units"
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/trigger quantity basis/i, error.message)
  end

  test "counterproposal-only response creates no confirmation link" do
    graph = build_unmanaged_activated_graph!("M3D9 Counter")
    reservation = create_and_request_reservation!(graph)
    result = respond!(
      reservation,
      outcomes: reservation.revisions.sole.scopes.map { |scope|
        [ scope.id, { outcome_kind: "counterproposed", supplier_note: "Different block" } ]
      }.to_h,
      with_evidence: false
    )

    assert_equal :created, result.status
    assert result.record.scope_outcomes.all?(&:counterproposed?)
    assert_equal 0, SupplierConfirmation.where(
      supplier_arrangement_id: graph[:arrangement].id
    ).count
    assert_equal 0, SupplierConfirmationReservationResponseLink.where(
      supplier_reservation_id: reservation.id
    ).count
  end

  test "successor revision copy rejects undefined occurrence on target version" do
    graph = build_unmanaged_activated_graph!("M3D9 Successor")
    reservation = create_and_request_reservation!(graph)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      arrangement_lock_version: graph[:arrangement].lock_version,
      version_lock_version: graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    ServiceOccurrenceDefinition.connection.execute(<<~SQL)
      DELETE FROM service_occurrence_definitions
      WHERE supplier_arrangement_version_id = '#{successor.id}'
    SQL

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierReservationRevision.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: { supplier_arrangement_version_id: successor.id },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/Service Occurrence is not defined/i, error.message)
  end

  test "revision and request reject booking supplier that is no longer eligible" do
    provider = create_capacity_supplier(@agency, "M3D9 Provider Only")
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: provider,
      prefix: "M3D9 Eligibility", capacity_management: "unmanaged"
    )
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      attributes: {
        booking_supplier_id: provider.id,
        supplier_arrangement_version_id: graph[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record

    planned = reservation.revisions.where(status: "planned").sole
    AbandonPlannedSupplierReservation.new(
      agency: @agency, actor: @actor, reservation: reservation,
      reason: "Reset for eligibility proof",
      revision_lock_version: planned.lock_version
    ).call
    graph[:item_definition].update!(default_service_provider: @supplier)
    graph[:occurrence_definition].update!(service_provider: nil)

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierReservationRevision.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: {
          scopes: [ { target_kind: "arrangement", label: "Revised whole" } ]
        },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/contracting supplier or an effective provider/i, error.message)

    graph[:item_definition].update!(default_service_provider: provider)
    graph[:occurrence_definition].update!(service_provider: provider)
    CreateSupplierReservationRevision.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { scopes: [ { target_kind: "arrangement", label: "Whole again" } ] },
      idempotency_key: SecureRandom.uuid
    ).call
    graph[:item_definition].update!(default_service_provider: @supplier)
    graph[:occurrence_definition].update!(service_provider: nil)
    activate_graph!(graph)

    error = assert_raises(AgencyCommand::Error) do
      RecordSupplierReservationRequest.new(
        agency: @agency, actor: @actor, reservation: reservation,
        attributes: { channel: "email", reference_note: "Sent" },
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/contracting supplier or an effective provider/i, error.message)
  end

  test "rails and database reject incompatible event outcome pairs" do
    graph = build_unmanaged_activated_graph!("M3D9 Outcome")
    reservation = create_and_request_reservation!(graph)
    revision = reservation.revisions.sole
    scope = revision.scopes.order(:position).first
    request_event = revision.events.find_by!(event_kind: "request")

    incompatible = SupplierReservationEventScopeOutcome.new(
      agency: @agency, departure: @departure, supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version], supplier_reservation: reservation,
      supplier_reservation_revision: revision, supplier_reservation_event: request_event,
      supplier_reservation_scope: scope, outcome_kind: "confirmed"
    )
    assert_not incompatible.valid?
    assert_includes incompatible.errors[:outcome_kind], "is not compatible with the parent event"

    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservationEventScopeOutcome.connection.execute(<<~SQL)
        INSERT INTO supplier_reservation_event_scope_outcomes (
          id, agency_id, departure_id, supplier_arrangement_id,
          supplier_arrangement_version_id, supplier_reservation_id,
          supplier_reservation_revision_id, supplier_reservation_event_id,
          supplier_reservation_scope_id, outcome_kind, created_at, updated_at
        ) VALUES (
          '#{SecureRandom.uuid_v7}',
          '#{@agency.id}',
          '#{@departure.id}',
          '#{graph[:arrangement].id}',
          '#{graph[:version].id}',
          '#{reservation.id}',
          '#{revision.id}',
          '#{request_event.id}',
          '#{scope.id}',
          'confirmed',
          NOW(),
          NOW()
        )
      SQL
    end
    assert_match(/incompatible with parent event/i, error.message)
  end

  test "database rejects capacity pool scope without version definition" do
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: "M3D9 Pool", capacity_management: "managed"
    )
    pair = classify_capacity_graph_pair(graph)
    pool = CapacityPool.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: @supplier,
      inventory_mode: "block",
      measurement_basis: "resource_units",
      effective_time_zone: graph[:occurrence_definition].time_zone
    )
    CapacityPoolDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair,
      capacity_pool: pool,
      label: "M3D9 pool",
      normalized_label: "m3d9 pool",
      unit_label: "cabins",
      proposed_opening_quantity: 4,
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Contract",
      override: false,
      position: 1
    )
    revision = SupplierReservation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: graph[:arrangement],
      booking_supplier: @supplier
    ).revisions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version], revision_number: 1, status: "planned",
      actor: @actor
    )
    graph[:version].capacity_pool_definitions.where(capacity_pool_id: pool.id).delete_all

    error = assert_raises(ActiveRecord::StatementInvalid) do
      SupplierReservationScope.connection.execute(<<~SQL)
        INSERT INTO supplier_reservation_scopes (
          id, agency_id, departure_id, supplier_arrangement_id, supplier_reservation_id,
          supplier_arrangement_version_id, supplier_reservation_revision_id,
          position, target_kind, arrangement_item_id, service_occurrence_id,
          supplier_resource_id, capacity_pool_id, created_at, updated_at
        ) VALUES (
          '#{SecureRandom.uuid_v7}',
          '#{@agency.id}',
          '#{@departure.id}',
          '#{graph[:arrangement].id}',
          '#{revision.supplier_reservation_id}',
          '#{graph[:version].id}',
          '#{revision.id}',
          1,
          'capacity_pool',
          '#{graph[:item].id}',
          '#{graph[:occurrence].id}',
          '#{graph[:resource].id}',
          '#{pool.id}',
          NOW(),
          NOW()
        )
      SQL
    end
    assert_match(/requires a version definition/i, error.message)
  end

  private

  def build_unmanaged_activated_graph!(prefix)
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: prefix, capacity_management: "unmanaged"
    )
    activate_graph!(graph)
    graph
  end

  def activate_graph!(graph)
    unless @departure.active?
      @departure.update!(
        status: "active",
        departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
        first_activated_at: Time.current
      )
    end
    graph[:version].update!(status: "activated", activated_at: Time.current)
    graph[:arrangement].update!(status: "active", governing_version: graph[:version])
  end

  def create_and_request_reservation!(graph)
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      attributes: {
        booking_supplier_id: graph[:arrangement].contracting_supplier_id,
        supplier_arrangement_version_id: graph[:version].id,
        scopes: [
          { target_kind: "arrangement", label: "Whole" },
          {
            target_kind: "occurrence",
            service_occurrence_id: graph[:occurrence].id,
            requested_quantity: 12,
            quantity_basis: "traveler_positions",
            label: "Arrival service"
          }
        ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    request_reservation(reservation)
    reservation
  end

  def request_reservation(reservation)
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def other_scopes_declined(reservation, except:)
    reservation.revisions.sole.scopes.reject { |scope| scope.id == except }.to_h do |scope|
      [ scope.id, { outcome_kind: "declined", decline_reason: "Not this scope" } ]
    end
  end

  def respond!(reservation, outcomes:, with_evidence: true)
    attributes = {
      channel: "portal",
      reference_note: "Response note",
      outcomes: outcomes
    }
    if with_evidence
      attributes[:evidence] = {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Response note",
        confirmed_without_identifier_reason: "Supplier will issue later"
      }
    end
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      attributes: attributes,
      idempotency_key: SecureRandom.uuid
    ).call
  end
end
