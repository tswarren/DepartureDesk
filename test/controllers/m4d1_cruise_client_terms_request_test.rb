# frozen_string_literal: true

require "test_helper"

class M4d1CruiseClientTermsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(agency: @agency, first_name: "Group", last_name: "Desk", status: "active")
    @arrangement, @version, @item, @ocean = cruise_with_cabins
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: @arrangement, resource: @ocean,
      expected_cabins: { double: 1 }, version_lock_version: @version.reload.lock_version
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: @arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: @version.id,
        use_tentative_draft: true, arrangement_lock_version: @version.reload.lock_version,
        arrangement_item_id: @item.id, supplier_resource_ids: [ @ocean.id ]
      }
    ).call
  end

  test "viewer is not found" do
    sign_in_as @viewer
    get departure_arrangement_cruise_client_terms_path(@departure, @arrangement)
    assert_response :not_found
  end

  test "preview and supplier copy review do not write" do
    sign_in_as @staff
    offer = ServiceOffer.find_by!(intended_arrangement_item_id: @item.id)
    option = offer.editable_draft_version.choice_options.sole
    assert_no_difference [ "ServiceOfferPriceDefinition.count", "AuditEvent.count", "ServiceOfferVersion.count" ] do
      post preview_departure_arrangement_cruise_client_terms_path(@departure, @arrangement), params: {
        option_id: option.id,
        rows: { cruise_fare: { label: "Cruise fare", first: "10.00", second: "" } }
      }
    end
    assert_response :success
    assert_match "Preview", response.body
    assert_match "pending", response.body

    assert_no_difference [ "ServiceOfferPriceDefinition.count", "AuditEvent.count" ] do
      get departure_arrangement_cruise_client_terms_path(@departure, @arrangement, editor: "edit", option_id: option.id, copy: "review")
    end
    assert_response :success
    assert_match "Review Supplier copy", response.body
  end

  test "an unsupported new cell returns 422 and keeps the editor open" do
    sign_in_as @staff
    offer = ServiceOffer.find_by!(intended_arrangement_item_id: @item.id)
    option = offer.editable_draft_version.choice_options.sole
    version = offer.editable_draft_version
    post departure_arrangement_cruise_client_terms_path(@departure, @arrangement), params: {
      option_id: option.id,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      rows: { cruise_fare: { label: "Cruise fare", first: "10.00", second: "10.00", additional: "5.00" } }
    }
    assert_response :unprocessable_entity
    assert_match "form-error-summary", response.body
    assert_match "10.00", response.body
  end

  test "preview subtracts a discount through the client price evaluator" do
    sign_in_as @staff
    offer = ServiceOffer.find_by!(intended_arrangement_item_id: @item.id)
    option = offer.editable_draft_version.choice_options.sole
    assert_no_difference [ "ServiceOfferPriceDefinition.count", "ServiceOfferPriceComponent.count" ] do
      post preview_departure_arrangement_cruise_client_terms_path(@departure, @arrangement), params: {
        option_id: option.id,
        rows: {
          cruise_fare: { label: "Cruise fare", first: "1624.00", second: "1624.00" },
          nccf: { label: "NCCF", first: "320.00", second: "320.00" },
          taxes_fees: { label: "Taxes and fees", first: "137.00", second: "137.00" },
          discount: { label: "Discount", first: "150.00", second: "150.00" }
        }
      }
    end
    assert_response :success
    assert_match "$3,862.00", response.body
    assert_no_match "4,462", response.body
  end

  test "preview keeps a submitted supplier source" do
    sign_in_as @staff
    offer = ServiceOffer.find_by!(intended_arrangement_item_id: @item.id)
    option = offer.editable_draft_version.choice_options.sole
    source_id = SecureRandom.uuid
    post preview_departure_arrangement_cruise_client_terms_path(@departure, @arrangement), params: {
      option_id: option.id,
      rows: { cruise_fare: { label: "Cruise fare", first: "10.00", second: "10.00", source_first: source_id, provenance_first: "recopy" } }
    }
    assert_response :success
    assert_match source_id, response.body
    assert_match "recopy", response.body
  end

  test "staff sees the summary without an open editor" do
    sign_in_as @staff
    get departure_arrangement_cruise_client_terms_path(@departure, @arrangement)
    assert_response :success
    assert_match "Cruise Client terms", response.body
    assert_no_match "cruise-client-terms-form", response.body
    assert_match "O1 — Prime Oceanview", response.body
  end

  private

  def cruise_with_cabins
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency, actor: @staff, departure: @departure,
      arrangement_attributes: { name: "Celebrity group agreement", contracting_supplier_id: @contractor.id, supplier_contact_id: @contact.id },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: { name: "Western Caribbean", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York" },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    resource = CreateCruiseCabinCategorySetup.new(
      agency: @agency, actor: @staff, arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call.record.resource
    [ arrangement, version.reload, sailing.record.item, resource ]
  end
end
