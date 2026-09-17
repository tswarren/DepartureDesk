require "test_helper"

class M3d6IntegratedScenarioProofTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
  end

  test "celebrity-like activation reservation confirmation and search remain coherent" do
    supplier = create_capacity_supplier(@agency, "Celebrity Cruises")
    departure = create_capacity_departure(@agency, name: "Celebrity Beyond")
    activate_departure!(departure)
    graph = create_capacity_graph(
      agency: @agency,
      departure: departure,
      contractor: supplier,
      provider: supplier,
      prefix: "Celebrity O1",
      capacity_management: "unmanaged"
    )
    arrangement = graph[:arrangement]
    version = graph[:version]
    seed_forecast_ready_cost!(graph, label: "O1 contracted")
    activate_arrangement!(arrangement, version, supplier)

    assert_equal "active", arrangement.reload.status
    assert_equal version.id, arrangement.governing_version_id
    assert departure.reload.first_activated_at.present?

    reservation = RecordExistingConfirmedSupplierReservation.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        booking_supplier_id: supplier.id,
        scopes: {
          "0" => { target_kind: "arrangement", label: "Whole sailing" },
          "1" => {
            target_kind: "occurrence",
            service_occurrence_id: graph[:occurrence].id,
            requested_quantity: 8,
            quantity_basis: "traveler_positions",
            label: "Prime oceanview block"
          }
        },
        channel: "portal",
        reference_note: "Group 1119999 confirmed",
        evidence: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current,
          channel: "portal",
          reference_note: "Group 1119999 confirmed",
          confirmed_without_identifier_reason: "Group number recorded separately"
        },
        identifier: {
          identifier_type: "group_number",
          display_value: "1119999",
          issuer_context: "Celebrity portal"
        }
      }
    ).call.record

    assert_equal "confirmed", reservation.projection.reload.state
    assert SupplierIssuedIdentifier.exists?(
      supplier_arrangement_id: arrangement.id,
      normalized_value: "1119999"
    )

    search = SearchSupplierArrangements.call(
      agency: @agency, actor: @actor, query: "1119999", departure_id: departure.id
    )
    assert_equal arrangement.id, search.records.first.id

    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency, actor: @admin, supplier: supplier,
        status: "inactive", lock_version: supplier.reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code
  end

  test "vineyard-like coach reservation supports partial decline without confirmation links" do
    supplier = create_capacity_supplier(@agency, "Vineyard Coach Co")
    departure = create_capacity_departure(@agency, name: "Vineyard Tour")
    activate_departure!(departure)
    graph = create_capacity_graph(
      agency: @agency,
      departure: departure,
      contractor: supplier,
      provider: supplier,
      prefix: "Vineyard coach",
      capacity_management: "unmanaged"
    )
    arrangement = graph[:arrangement]
    version = graph[:version]
    seed_forecast_ready_cost!(graph, label: "Coach fixed")
    activate_arrangement!(arrangement, version, supplier)

    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @actor, arrangement: arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        booking_supplier_id: supplier.id,
        scopes: {
          "0" => { target_kind: "arrangement", label: "Coach day" },
          "1" => {
            target_kind: "occurrence",
            service_occurrence_id: graph[:occurrence].id,
            requested_quantity: 40,
            quantity_basis: "traveler_positions",
            label: "Passenger seats"
          }
        }
      }
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @actor, reservation: reservation,
      idempotency_key: SecureRandom.uuid,
      attributes: { channel: "email", reference_note: "Coach request" }
    ).call

    scopes = reservation.revisions.sole.scopes.order(:position).to_a
    RecordSupplierReservationResponse.new(
      agency: @agency, actor: @actor, reservation: reservation,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        channel: "email",
        reference_note: "Partial coach response",
        outcomes: {
          scopes.first.id => { outcome_kind: "confirmed" },
          scopes.second.id => { outcome_kind: "declined", decline_reason: "Seat block unavailable" }
        },
        evidence: {
          evidence_kind: "supplier_message",
          evidence_on: Date.current,
          channel: "email",
          reference_note: "Coach confirmed with seat decline",
          confirmed_without_identifier_reason: "No coach confirmation number"
        }
      }
    ).call

    projection = reservation.projection.reload
    assert_equal "partially_confirmed", projection.state
    assert_equal 1, projection.confirmed_scope_count
    assert_equal 1, projection.declined_scope_count
    assert SupplierConfirmationReservationResponseLink.exists?(supplier_reservation_id: reservation.id)
  end

  test "arrangement search page query count stays bounded" do
    supplier = create_capacity_supplier(@agency, "Query Supplier")
    departure = create_capacity_departure(@agency, name: "Query Departure")
    activate_departure!(departure)
    3.times do |index|
      graph = create_capacity_graph(
        agency: @agency,
        departure: departure,
        contractor: supplier,
        provider: supplier,
        prefix: "Query Arrangement #{index}",
        capacity_management: "unmanaged"
      )
      seed_forecast_ready_cost!(graph, label: "Query cost #{index}")
      activate_arrangement!(graph[:arrangement], graph[:version], supplier)
    end

    queries = count_queries do
      SearchSupplierArrangements.call(agency: @agency, actor: @actor, departure_id: departure.id, query: "Query")
    end
    assert_operator queries, :<=, 12
  end

  private

  def activate_departure!(departure)
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
  end

  def seed_forecast_ready_cost!(graph, label:)
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: graph[:arrangement].departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      charging_supplier: graph[:arrangement].contracting_supplier,
      label: label,
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: graph[:arrangement].departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included",
      currency: "USD",
      forecast_ready_by: @actor,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:#{SecureRandom.hex(8)}",
      readiness_provenance: "Signed"
    )
  end

  def activate_arrangement!(arrangement, version, supplier)
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      version: version,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.lock_version,
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Activated for M3D.6 proof",
        confirmed_without_identifier_reason: "Proof activation"
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, **) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
