require "test_helper"

class M4ACelebrityVineyardProofTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity O1 can be offered from Item Occurrence Resource or Pool without inventing Client fares" do
    cruise = m3f_activated_graph!(
      "M4A Celebrity",
      "Celebrity Beyond M4A",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    m3f_create_celebrity_o1_cost!(cruise)
    cruise[:pool] = m3f_add_numeric_pool!(cruise, quantity: 8, label: "O1 cabins")
    pool = cruise[:pool]

    item_offer = create_from_source(cruise, title: "O1 item", occurrence: false, resource: false, pool: false)
    occurrence_offer = create_from_source(cruise, title: "O1 sailing", occurrence: true, resource: false, pool: false)
    resource_offer = create_from_source(cruise, title: "O1 cabin type", occurrence: false, resource: true, pool: false)
    pool_offer = create_from_source(cruise, title: "O1 cabin block", occurrence: true, resource: true, pool: true)

    [ item_offer, occurrence_offer, resource_offer, pool_offer ].each do |offer|
      definition = offer.editable_draft_version.definition
      assert definition.m3_backed?
      assert_not_includes definition.attributes.keys, "price_minor_units"
      assert_no_match(/\d{3,}/, definition.client_title)
    end

    assert_nil item_offer.editable_draft_version.source_bindings.sole.service_occurrence_id
    assert_equal cruise[:occurrence].id, occurrence_offer.editable_draft_version.source_bindings.sole.service_occurrence_id
    assert_equal cruise[:resource].id, resource_offer.editable_draft_version.source_bindings.sole.supplier_resource_id
    assert_equal pool.id, pool_offer.editable_draft_version.source_bindings.sole.capacity_pool_id
    assert_nil ServiceOffer.column_names.find { |name| name.include?("fare") }
  end

  test "Vineyard keeps distinct drafts and dinner as two Items not a choice group" do
    graph = m3f_activated_graph!(
      "M4A Vineyard",
      "Vineyard Tour M4A",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    m3f_create_vineyard_costs!(graph)
    m3f_add_dinner_items!(graph)
    lodging = m3f_secondary_arrangement_graph!(
      departure: graph[:departure],
      supplier_name: "Hotel A shape",
      prefix: "Hotel A",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 6)
    )
    hotel_b = m3f_secondary_arrangement_graph!(
      departure: graph[:departure],
      supplier_name: "Hotel B shape",
      prefix: "Hotel B",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 6)
    )

    coach = create_from_source(graph, title: "Coach transfer")
    tasting = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Winery tasting", fulfillment_basis: "on_request" }
    ).call.record
    lunches = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Included lunches", fulfillment_basis: "agency_fulfilled" }
    ).call.record
    hotel_a_offer = create_from_source(lodging, title: "Hotel A lodging")
    hotel_b_offer = create_from_source(hotel_b, title: "Hotel B lodging")

    dinners = graph[:version].arrangement_item_definitions.where("name LIKE ?", "%Dinner%").order(:position)
    assert_equal [ "Standard Dinner", "Deluxe Dinner" ], dinners.map(&:name)
    dinner_offers = dinners.map { |definition|
      CreateServiceOfferFromSource.new(
        agency: @agency, actor: @actor, departure: graph[:departure], idempotency_key: SecureRandom.uuid,
        attributes: {
          supplier_arrangement_id: graph[:arrangement].id,
          supplier_arrangement_version_id: graph[:version].id,
          arrangement_item_id: definition.arrangement_item_id,
          client_title: definition.name
        }
      ).call.record
    }

    titles = [ coach, tasting, lunches, hotel_a_offer, hotel_b_offer, *dinner_offers ].map { |offer|
      offer.editable_draft_version.definition.client_title
    }
    assert_equal titles, titles.uniq
    dinner_offers.each do |offer|
      binding = offer.editable_draft_version.source_bindings.sole
      assert binding.required?
      assert_nil binding.alternative_group_key
    end
    assert_not_equal hotel_a_offer.id, hotel_b_offer.id
  end

  private

  def create_from_source(graph, title:, occurrence: true, resource: false, pool: false)
    attrs = {
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      client_title: title
    }
    attrs[:service_occurrence_id] = graph[:occurrence].id if occurrence
    attrs[:supplier_resource_id] = graph[:resource].id if resource
    attrs[:capacity_pool_id] = graph[:pool]&.id if pool
    CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: graph[:departure],
      idempotency_key: SecureRandom.uuid, attributes: attrs
    ).call.record
  end
end
