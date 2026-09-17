require "test_helper"

class M3BCapacityRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "M3B Capacity Request")
    @contractor = create_capacity_supplier(@agency, "M3B Request Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Request Provider")
  end

  test "staff configures draft capacity from the item workspace" do
    graph = create_capacity_graph(capacity_management: nil)
    sign_in_as @staff

    get departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item])
    assert_response :success
    assert_match "Draft capacity", response.body
    assert_match "Not decided", response.body

    patch departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item]), params: {
      arrangement_item_definition: {
        capacity_management: "managed",
        lock_version: graph[:item_definition].lock_version
      }
    }
    assert_redirected_to departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item])
    assert_equal "managed", graph[:item_definition].reload.capacity_management

    assert_difference -> { CapacityPairDefinition.count }, 1 do
      patch pair_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], graph[:occurrence], graph[:resource]), params: {
        version_lock_version: graph[:version].reload.lock_version,
        classification: "pooled"
      }
    end
    pair = graph[:version].capacity_pair_definitions.sole
    assert_equal "pooled", pair.classification

    assert_difference -> { CapacityPool.count }, 1 do
      post pair_pools_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: graph[:version].reload.lock_version,
        capacity_pool: pool_params(label: "Cabin block", quantity: 8)
      }
    end
    first_pool = pair.capacity_pool_definitions.order(:position).first.capacity_pool
    assert_redirected_to departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], anchor: "capacity-pool-#{first_pool.id}")

    post pair_pools_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: graph[:version].reload.lock_version,
      capacity_pool: pool_params(label: "Overflow request", inventory_mode: "on_request", quantity: nil, evidence: false)
    }
    second_pool = pair.capacity_pool_definitions.order(:position).last.capacity_pool

    patch reorder_pair_pools_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id), params: {
      version_lock_version: graph[:version].reload.lock_version,
      capacity_pool_ids: [ second_pool.id, first_pool.id ]
    }
    assert_equal [ second_pool.id, first_pool.id ], pair.capacity_pool_definitions.order(:position).pluck(:capacity_pool_id)

    first_definition = first_pool.definitions.sole
    patch pair_pool_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id, id: first_pool.id), params: {
      capacity_pool: pool_params(label: "Updated cabin block", quantity: 9).merge(lock_version: first_definition.lock_version)
    }
    assert_redirected_to departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], anchor: "capacity-pool-#{first_pool.id}")
    assert_equal "Updated cabin block", first_definition.reload.label
    assert_equal 9, first_definition.proposed_opening_quantity

    [ second_pool, first_pool ].each do |pool|
      definition = pool.definitions.sole
      delete pair_pool_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id, id: pool.id), params: {
        version_lock_version: graph[:version].reload.lock_version,
        lock_version: definition.lock_version
      }
      assert_redirected_to departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item])
      assert_not CapacityPool.exists?(pool.id)
    end

    delete defined_pair_departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item], pair_id: pair.id), params: {
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: pair.reload.lock_version
    }
    assert_redirected_to departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item])
    assert_not CapacityPairDefinition.exists?(pair.id)
  end

  test "arrangement item cards summarize capacity without viewer controls" do
    graph = create_capacity_graph
    pair = ClassifyCapacityPair.new(
      agency: @agency,
      actor: @admin,
      item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      classification: "pooled",
      version_lock_version: graph[:version].reload.lock_version
    ).call.record
    CreateCapacityPool.new(
      agency: @agency,
      actor: @admin,
      pair: pair,
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: pool_params(label: "Viewer pool", quantity: 4)
    ).call

    sign_in_as @viewer
    get departure_arrangement_path(@departure, graph[:arrangement])
    assert_response :success
    assert_match "Capacity", response.body
    assert_match "Managed capacity", response.body
    assert_select "a", text: "Configure capacity", count: 0

    get departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item])
    assert_response :success
    assert_match "Viewer pool", response.body
    assert_match "Proposed opening quantity", response.body
    assert_select "input[type=submit]", count: 0

    patch departure_arrangement_item_capacity_path(@departure, graph[:arrangement], graph[:item]), params: {
      arrangement_item_definition: {
        capacity_management: "unmanaged",
        lock_version: graph[:item_definition].reload.lock_version
      }
    }
    assert_redirected_to root_path
    assert_equal "managed", graph[:item_definition].reload.capacity_management
  end

  test "capacity routes return not found for another agency graph" do
    other_agency = agencies(:cove)
    other_departure = create_capacity_departure(other_agency, name: "Cove Capacity")
    other_contractor = create_capacity_supplier(other_agency, "Cove Capacity Contractor")
    other_provider = create_capacity_supplier(other_agency, "Cove Capacity Provider")
    graph = create_capacity_graph(
      agency: other_agency,
      departure: other_departure,
      contractor: other_contractor,
      provider: other_provider
    )

    sign_in_as @admin

    get departure_arrangement_item_capacity_path(other_departure, graph[:arrangement], graph[:item])
    assert_response :not_found
    patch pair_departure_arrangement_item_capacity_path(other_departure, graph[:arrangement], graph[:item], graph[:occurrence], graph[:resource]), params: {
      version_lock_version: graph[:version].lock_version,
      classification: "pooled"
    }
    assert_response :not_found
    assert_empty graph[:version].capacity_pair_definitions
  end

  test "staff bulk classifies reviewed pairs and configures a pooled pair with its first Pool" do
    bulk_graph = create_capacity_graph(prefix: "Bulk request")
    second_resource = bulk_graph[:item].supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: bulk_graph[:arrangement]
    )
    bulk_graph[:version].supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: bulk_graph[:arrangement],
      arrangement_item: bulk_graph[:item],
      supplier_resource: second_resource,
      name: "Second resource",
      position: 2
    )
    sign_in_as @staff

    get departure_arrangement_item_capacity_path(@departure, bulk_graph[:arrangement], bulk_graph[:item])
    assert_response :success
    assert_match "Review undecided capacity pairs", response.body
    assert_match "Classify as pooled and add first Pool", response.body

    patch departure_arrangement_item_bulk_capacity_pairs_path(
      @departure, bulk_graph[:arrangement], bulk_graph[:item]
    ), params: {
      version_lock_version: bulk_graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      decisions: {
        "first" => {
          selected: "1",
          service_occurrence_id: bulk_graph[:occurrence].id,
          supplier_resource_id: bulk_graph[:resource].id,
          classification: "pooled"
        },
        "second" => {
          selected: "1",
          service_occurrence_id: bulk_graph[:occurrence].id,
          supplier_resource_id: second_resource.id,
          classification: "not_applicable"
        }
      }
    }
    assert_redirected_to departure_arrangement_item_capacity_path(
      @departure, bulk_graph[:arrangement], bulk_graph[:item]
    )
    assert_equal %w[not_applicable pooled],
      bulk_graph[:version].capacity_pair_definitions.order(:classification).pluck(:classification)

    setup_graph = create_capacity_graph(prefix: "Pool setup request")
    post departure_arrangement_item_capacity_pair_pool_setup_path(
      @departure,
      setup_graph[:arrangement],
      setup_graph[:item],
      setup_graph[:occurrence],
      setup_graph[:resource]
    ), params: {
      version_lock_version: setup_graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      capacity_pool: pool_params(label: "First room block", quantity: 8)
    }
    pool = setup_graph[:arrangement].capacity_pools.sole
    assert_redirected_to departure_arrangement_item_capacity_path(
      @departure, setup_graph[:arrangement], setup_graph[:item], anchor: "capacity-pool-#{pool.id}"
    )
    assert_predicate setup_graph[:version].capacity_pair_definitions.sole, :pooled?
    assert_equal pool.id, setup_graph[:version].capacity_pool_definitions.sole.capacity_pool_id
  end

  private

  def pool_params(label:, quantity:, inventory_mode: "block", evidence: true)
    params = {
      inventory_mode: inventory_mode,
      measurement_basis: "resource_units",
      label: label,
      unit_label: "cabins",
      proposed_opening_quantity: quantity
    }
    if evidence
      params.merge!(
        evidence_kind: "contract",
        evidence_on: "2026-05-01",
        evidence_reference_note: "Contracted capacity"
      )
    end
    params
  end
end
