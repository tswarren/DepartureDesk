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
    assert_match "There is no Publish action in this slice.", response.body
    assert_select "a", text: "Publish", count: 0
    assert_select "input[type=submit][value=Publish]", count: 0
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
    get departure_path(@departure)
    assert_response :success
    assert_select "h2.dd-panel-title", text: "Client offers (draft)"
    assert_select "a", text: "Add service from Supplier planning"
    assert_select "a", text: "Add explicit-basis service"
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
    assert_select "input[name=version_lock_version]", count: 1

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
