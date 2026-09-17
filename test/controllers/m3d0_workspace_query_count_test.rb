require "test_helper"

class M3D0WorkspaceQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M3D.0 bounded workspace")
    @contractor = create_capacity_supplier(@agency, "Workspace contractor")
    @provider = create_capacity_supplier(@agency, "Workspace provider")
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @contractor,
      name: "Vineyard planning workspace"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
    sign_in_as @actor
  end

  test "arrangement profile GET stays bounded from two to ten Items" do
    2.times { |index| create_workspace_item(index) }
    path = departure_arrangement_path(@departure, @arrangement)

    get path
    two_items = request_query_count { get path }

    8.times { |index| create_workspace_item(index + 2) }
    get path
    ten_items = request_query_count { get path }

    assert_operator ten_items, :<=, two_items + 2,
      "expected bounded profile queries, got #{two_items} for two Items and #{ten_items} for ten"
  end

  test "arrangement profile evaluates one forecast for the page" do
    3.times { |index| create_workspace_item(index) }
    calls = 0
    trace = TracePoint.new(:call) do |event|
      if event.defined_class == EvaluateSupplierCostForecast && event.method_id == :initialize
        calls += 1
      end
    end

    trace.enable do
      get departure_arrangement_path(@departure, @arrangement)
    end

    assert_response :success
    assert_equal 1, calls
  end

  test "M3D activation Reservation and commitment routes remain absent" do
    route_contract = Rails.application.routes.routes.map do |route|
      [ route.name, route.defaults[:controller], route.defaults[:action] ].compact.join(" ")
    end.join("\n")

    assert_no_match(/\breservations?\b/i, route_contract)
    assert_no_match(/\bconfirmations?\b/i, route_contract)
    assert_no_match(/activate[_ -]?arrangement/i, route_contract)
    assert_no_match(/\bcommitments?\b/i, route_contract)
  end

  private

  def create_workspace_item(index)
    result = CreateArrangementItemSetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      item_attributes: {
        name: format("Workspace Item %02d", index),
        category: "lodging",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: format("Occurrence %02d", index),
        starts_on: Date.new(2026, 6, 1) + index,
        ends_on: Date.new(2026, 6, 1) + index,
        time_zone: "UTC"
      },
      resource_attributes: { name: format("Resource %02d", index) }
    ).call
    result.record.item
  end

  def request_query_count
    queries = []
    callback = ->(*, payload) do
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end
end
