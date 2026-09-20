# frozen_string_literal: true

require "test_helper"

# M3F.3 hardening gate — only closes named M3F.2 findings plus parent exit-14 proof
# assigned to hardening when the finding log is empty of blockers.
class M3f3HardeningGateTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @other_agency = agencies(:cove)
  end

  test "cross-agency identifiers stay not found and client commercial tables remain absent" do
    graph = m3f_activated_graph!(
      "M3F3 Tenancy",
      "M3F3 Isolation Departure",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    m3f_activate!(graph)

    assert_equal 0,
      SupplierArrangement.where(agency_id: @other_agency.id, id: graph[:arrangement].id).count
    assert_nil @other_agency.departures.find_by(id: graph[:departure].id)
    assert_nil @other_agency.supplier_arrangements.find_by(id: graph[:arrangement].id)

    m3f_assert_no_client_commercial_tables!
    assert_not ActiveRecord::Base.connection.data_source_exists?("travel_programs")
  end

  test "exposure rebuild preserves vineyard illustrative forecast totals" do
    graph = m3f_activated_graph!(
      "M3F3 Rebuild",
      "Vineyard Rebuild",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    m3f_create_vineyard_costs!(graph)
    m3f_activate!(graph)

    before = SupplierExposureSummary.find_by!(
      supplier_arrangement: graph[:arrangement], qualification_band: "forecast"
    )
    before_gross = before.gross_minor_units
    before_net = before.expected_net_minor_units

    RebuildSupplierExposureProjection.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement]
    ).call

    after = SupplierExposureSummary.find_by!(
      supplier_arrangement: graph[:arrangement], qualification_band: "forecast"
    )
    assert_equal before_gross, after.gross_minor_units,
      "Rebuild repairs projections only (ledger=#{LEDGER_ILLUSTRATIVE})"
    assert_equal before_net, after.expected_net_minor_units
  end
end
