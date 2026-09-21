require "test_helper"

class ServiceOffersRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Request Contractor")
    @departure = create_capacity_departure(@agency, name: "Request Offer Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Request"
    )
  end

  test "staff creates an explicit-basis draft and sees form recovery" do
    sign_in_as @staff

    get new_departure_service_offer_path(@departure)
    assert_response :success
    assert_select "input[name=idempotency_key]", count: 1
    assert_select "h1.dd-page-title", text: "Add explicit-basis service"

    key = SecureRandom.uuid
    post departure_service_offers_path(@departure), params: {
      idempotency_key: key,
      service_offer: { client_title: "", fulfillment_basis: "on_request" }
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "input[name=idempotency_key][value=?]", key

    assert_difference -> { @departure.service_offers.count }, 1 do
      post departure_service_offers_path(@departure), params: {
        idempotency_key: SecureRandom.uuid,
        service_offer: { client_title: "Travel insurance", fulfillment_basis: "on_request" }
      }
    end
    offer = @departure.service_offers.find_by!(name: "Travel insurance")
    assert_redirected_to departure_service_offer_path(@departure, offer)

    get departure_service_offer_path(@departure, offer)
    assert_response :success
    assert_match "Travel insurance", response.body
    assert_match "Publish freezes this standalone version", response.body
    assert_select "input[type=submit][value=Publish]", count: 1
    assert_select "input[name='service_offer[lock_version]']", count: 0
  end

  test "staff creates from the governing source picker" do
    sign_in_as @staff
    get from_source_departure_service_offers_path(@departure)
    assert_response :success
    assert_match "Tentative draft", response.body
    assert_select "input[name='service_offer[source_key]']"

    candidate_key = offer_source_key_for(@graph)
    post from_source_departure_service_offers_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      service_offer: {
        source_key: candidate_key,
        client_title: "Client cabin"
      }
    }
    offer = @departure.service_offers.order(:created_at).last
    assert_redirected_to departure_service_offer_path(@departure, offer)
    assert_equal "Client cabin", offer.editable_draft_version.definition.client_title
  end

  test "viewer cannot read unpublished offers and sees no CTAs" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Hidden draft", fulfillment_basis: "on_request" }
    ).call.record

    sign_in_as @viewer
    get departure_path(@departure)
    assert_response :success
    assert_select "h2.dd-panel-title", text: "Client offers (draft)", count: 0
    assert_select "a", text: "Add service from Supplier planning", count: 0
    assert_select "a", text: "Add explicit-basis service", count: 0

    get departure_service_offers_path(@departure)
    assert_response :not_found
    get departure_service_offer_path(@departure, offer)
    assert_response :not_found
    get new_departure_service_offer_path(@departure)
    assert_response :not_found
    get from_source_departure_service_offers_path(@departure)
    assert_response :not_found
  end

  test "staff see client-offer CTAs on the departure" do
    sign_in_as @staff
    CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Main", component_name: "Coach", placement: "included" }
    ).call
    get departure_path(@departure)
    assert_redirected_to departure_builder_path(@departure)
    follow_redirect!
    assert_response :success
    assert_select "a", text: "Client offers"
    assert_select "a", text: "Packages"
    assert_select "a", text: "Supplier planning"
  end

  test "cross-agency offer routes are not found" do
    other_agency = agencies(:cove)
    other_actor = agency_users(:cove_admin)
    other_departure = create_capacity_departure(other_agency, name: "Cove Offer Departure")
    other_offer = CreateServiceOfferWithExplicitBasis.new(
      agency: other_agency, actor: other_actor, departure: other_departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Foreign offer", fulfillment_basis: "on_request" }
    ).call.record

    sign_in_as @staff
    get departure_service_offer_path(other_departure, other_offer)
    assert_response :not_found
    get departure_service_offers_path(other_departure)
    assert_response :not_found
  end

  test "staff edits and discards a draft through confirmation" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "To edit", fulfillment_basis: "agency_fulfilled" }
    ).call.record
    sign_in_as @staff

    get edit_departure_service_offer_path(@departure, offer)
    assert_response :success
    assert_select "input[name='service_offer[lock_version]']"
    assert_select "input[name=version_lock_version]"
    assert_select "input[name='service_offer[reselect_current_sources]']", count: 0

    patch departure_service_offer_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      service_offer: {
        lock_version: offer.lock_version,
        name: offer.name,
        client_title: "Edited title"
      }
    }
    assert_redirected_to departure_service_offer_path(@departure, offer)
    assert_equal "Edited title", offer.editable_draft_version.definition.reload.client_title

    get discard_departure_service_offer_path(@departure, offer)
    assert_response :success
    post discard_departure_service_offer_path(@departure, offer), params: {
      reason: "No longer selling",
      offer_lock_version: offer.reload.lock_version,
      version_lock_version: offer.editable_draft_version.lock_version
    }
    assert_redirected_to departure_path(@departure)
    assert_equal "abandoned", offer.versions.first.reload.status
  end

  test "staff can reselect the current activated source from the ordinary edit form" do
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        supplier_arrangement_id: @graph[:arrangement].id,
        arrangement_item_id: @graph[:item].id,
        client_title: "Cabin to reselect",
        client_description: "Keep this description"
      }
    ).call.record
    sign_in_as @staff

    get edit_departure_service_offer_path(@departure, offer)
    assert_response :success
    assert_select "input[name='service_offer[reselect_current_sources]']"
    assert_select "input[name='service_offer[refresh_bindings]']"
  end

  test "staff saves an ordinary client price from show without a percentage-base table" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Priced draft", fulfillment_basis: "on_request" }
    ).call.record

    sign_in_as @staff
    get departure_service_offer_path(@departure, offer)
    assert_response :success
    assert_select "h2.dd-panel-title", text: "Client price"
    assert_select "label", text: "Ordinary pattern"
    assert_select "input[id=price_amount]"
    assert_select "details" do
      assert_select "summary", text: "Advanced price details"
    end
    assert_no_match(/forecast_supplier_cost|Scenario margin/i, response.body)
    assert_select "dt", text: "Scenario margin", count: 0

    post departure_service_offer_price_path(@departure, offer), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      price: { pattern: "per_person", amount: "125.00" }
    }
    assert_redirected_to departure_service_offer_path(@departure, offer)
    follow_redirect!
    assert_match "Client price saved.", response.body
    assert_match "$125.00", response.body
    assert_select "dt", text: "Scenario margin", count: 0
    assert_select "button", text: "Add component"
    assert_select "template[data-price-component-fields-target=template]"
    assert_select "button", text: "Add occupancy position"
  end

  test "staff preview charges mixed client rate categories against matching persons" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Mixed category", fulfillment_basis: "on_request" }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @staff, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: {
        components: [
          {
            label: "Adult", client_role: "base_price", calculation_kind: "unit_rate",
            amount: "100.00", quantity_basis: "persons", client_rate_category_key: "adult"
          },
          {
            label: "Child", client_role: "base_price", calculation_kind: "unit_rate",
            amount: "50.00", quantity_basis: "persons", client_rate_category_key: "child"
          }
        ]
      }
    ).call

    sign_in_as @staff
    post preview_departure_service_offer_price_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      scenario: {
        persons: 2,
        resource_units: 1,
        occupancy_positions: {
          "0" => { client_rate_category_key: "adult" },
          "1" => { client_rate_category_key: "child" }
        }
      }
    }
    assert_response :success
    assert_match "$150.00", response.body
    assert_no_match "$300.00", response.body
  end

  test "viewer cannot open price routes" do
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Hidden price", fulfillment_basis: "on_request" }
    ).call.record

    sign_in_as @viewer
    post departure_service_offer_price_path(@departure, offer), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      price: { pattern: "per_person", amount: "10.00" }
    }
    assert_response :not_found
  end

  private

  def offer_source_key_for(graph)
    [
      graph[:arrangement].id,
      graph[:version].id,
      graph[:item].id,
      graph[:occurrence].id,
      graph[:resource].id,
      nil,
      "1"
    ].join(":")
  end
end
