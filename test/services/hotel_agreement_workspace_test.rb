# frozen_string_literal: true

require "test_helper"

class HotelAgreementWorkspaceTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(time_zone: "America/New_York")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @contractor,
      prefix: "Hilton",
      category: "lodging"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @item = @graph[:item]
    record_stay!
  end

  test "assembles the stay and leaves uncovered deposits off the schedule" do
    create_deposit!(41_560, "2026-10-01", coverage: [])
    create_deadline!(coverage: [ { arrangement_item_id: @item.id } ])
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @admin, arrangement_item: @item, kind: "deposit_refund",
      governing_wording: "The deposit is refundable through November 20, 2027.",
      original_wording: "Deposits are non-refundable.",
      source_description: "Hilton group contract",
      idempotency_key: SecureRandom.uuid
    ).call

    workspace = compile

    assert_equal "Recorded", workspace.stay.state
    assert_equal Date.new(2027, 11, 4), workspace.stay.arrival_on
    assert_equal Date.new(2027, 11, 6), workspace.stay.departure_on
    assert_equal "America/New_York", workspace.stay.time_zone
    assert_empty workspace.deposits
    assert_equal 1, workspace.unassigned_deposits.size
    assert_equal [ Date.new(2027, 10, 3) ], workspace.deadlines.map(&:due_on)
    assert workspace.deadlines.none? { |row| row.due_on == Date.new(2027, 11, 20) }
    refund = workspace.terms.find { |term| term.kind == "deposit_refund" }
    assert_equal "Recorded", refund.state
    assert_equal "Not reviewed", workspace.terms.find { |term| term.kind == "destination_fee" }.state
    assert_equal "Draft", workspace.version.role
    assert_equal "Not Supplier confirmed", workspace.version.confirmation
    assert_equal "Not yet activated", workspace.version.activation
  end

  test "item coverage places the fixed deposits on the stay schedule" do
    [ [ 41_560, "2026-10-01" ], [ 187_020, "2027-05-07" ], [ 187_020, "2027-10-04" ] ].each do |amount, date|
      create_deposit!(amount, date, coverage: [ { arrangement_item_id: @item.id } ])
    end

    workspace = compile

    assert_equal [ "$415.60", "$1,870.20", "$1,870.20" ], workspace.deposits.map(&:amount_label)
    assert_empty workspace.unassigned_deposits
    assert workspace.deposits.all?(&:thin)
  end

  test "a confirmed successor keeps both role and confirmation" do
    @departure.update!(status: "active", departure_reference: "D-930210", first_activated_at: Time.current)
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @admin, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    SupplierConfirmation.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: successor, confirming_supplier: @contractor,
      actor: @admin, evidence_kind: "supplier_confirmation", evidence_on: Date.new(2026, 9, 28),
      channel: "email", reference_note: "Confirmed the Hotel terms.",
      confirmed_without_identifier_reason: "No hotel number was issued.", recorded_at: Time.current
    )

    workspace = HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement.reload,
      version: successor, item: @item
    ).call

    assert_equal "Proposed successor draft", workspace.version.role
    assert_equal "Supplier confirmed", workspace.version.confirmation
    assert_equal "Not yet activated", workspace.version.activation
    assert workspace.version.draft
    assert_equal "Based on current v#{@version.version_number}", workspace.version.lineage
    assert_equal @version.id, workspace.version.current_version_id

    governing = HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      version: @version, item: @item
    ).call
    assert_equal successor.id, governing.version.proposed_version_id
    assert_nil governing.version.lineage
  end

  private

  def compile
    HotelAgreementWorkspace.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      version: @version.reload, item: @item
    ).call
  end

  def record_stay!
    occurrence = @item.service_occurrences.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement, status: "planned"
    )
    @version.service_occurrence_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: @item, service_occurrence: occurrence, name: "Stay",
      starts_on: Date.new(2027, 11, 4), ends_on: Date.new(2027, 11, 6),
      starts_at_local: "15:00", ends_at_local: "12:00", time_zone: "America/New_York",
      service_provider: @contractor
    )
  end

  def create_deposit!(amount, date, coverage:)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: amount,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => date },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: coverage,
        cost_links: [],
        contributor_definition_ids: []
      }
    ).call
  end

  def create_deadline!(coverage:)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @admin, version: @version.reload,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        deadline_type: "rooming_list_due",
        kind: "actionable",
        rule_shape: "fixed_local_datetime",
        rule_parameters: { "datetime" => "2027-10-03T17:00:00" },
        precision: "local_date_time",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: coverage,
        commitment_lines: []
      }
    ).call
  end
end
