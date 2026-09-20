require "test_helper"

class SearchDepartureOfferSourcesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Search Contractor")
    @departure = create_capacity_departure(@agency, name: "Search Departure")
  end

  test "never-activated arrangements list only the labeled draft" do
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "DraftOnly"
    )
    outcome = SearchDepartureOfferSources.call(agency: @agency, actor: @actor, departure: @departure)

    assert outcome.records.all?(&:tentative)
    assert outcome.records.all? { |candidate| candidate.version.id == graph[:version].id }
    item_only = outcome.records.find { |candidate|
      candidate.item.id == graph[:item].id && candidate.occurrence.nil? && candidate.resource.nil?
    }
    item_resource = outcome.records.find { |candidate|
      candidate.item.id == graph[:item].id && candidate.occurrence.nil? && candidate.resource&.id == graph[:resource].id
    }
    assert item_only
    assert item_resource
  end

  test "active arrangements default to governing activated and list tentative draft as opt-in" do
    graph = build_activated_unestablished_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor,
      actor: @actor, prefix: "SearchActive"
    )
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: graph[:arrangement],
      arrangement_lock_version: graph[:arrangement].reload.lock_version,
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    outcome = SearchDepartureOfferSources.call(agency: @agency, actor: @actor, departure: @departure)
    governing = outcome.records.select { |candidate| candidate.version.id == graph[:version].id }
    tentative = outcome.records.select { |candidate| candidate.version.id == successor.id }

    assert governing.any?
    assert governing.none?(&:tentative)
    assert tentative.any?
    assert tentative.all?(&:tentative)
    assert_includes tentative.first.then { |row| [ row.arrangement.name, row.item_definition.name ].join(" ") },
      graph[:item_definition].name
  end

  test "viewer cannot search unpublished offer sources" do
    error = assert_raises(AgencyCommand::Error) do
      SearchDepartureOfferSources.call(agency: @agency, actor: @viewer, departure: @departure)
    end
    assert_equal :unauthorized, error.code
  end
end
