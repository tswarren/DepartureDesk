# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseClientTermsSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(agency: @agency, first_name: "Group", last_name: "Desk", status: "active")
  end

  test "staff enters a double fare and reopens it" do
    arrangement, version, item, ocean = cruise_with
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      expected_cabins: { double: 1 }, version_lock_version: version.reload.lock_version
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: version.id,
        use_tentative_draft: true, arrangement_lock_version: version.reload.lock_version,
        arrangement_item_id: item.id, supplier_resource_ids: [ ocean.id ]
      }
    ).call
    offer = ServiceOffer.find_by!(intended_arrangement_item_id: item.id)
    option = offer.editable_draft_version.choice_options.sole

    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit", option_id: option.id)
    assert_selector "h2", text: /Edit Client terms/
    assert_no_selector "th", text: "Single"
    fill_in "Cruise fare first", with: "1931.00"
    fill_in "Cruise fare second", with: "1931.00"
    fill_in "Agency fee first", with: "25.00"
    fill_in "Agency fee second", with: "25.00"
    fare = find_field("Cruise fare first")
    fare.send_keys(:tab)
    assert_field "Cruise fare second", focused: true
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width, 900)
      assert_selector "[aria-label='Client term matrix']"
      assert_no_page_overflow
    end
    click_button "Save Client terms"
    assert_text "Client terms created."
    assert_no_selector "#cruise-client-terms-form"
    click_link "Edit terms"
    assert_field "Cruise fare first", with: "1931.00"
    assert_field "Agency fee first", with: "25.00"
  end

  test "staff reviews a supplier copy before saving" do
    arrangement, version, item, ocean = cruise_with
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      expected_cabins: { double: 1 }, version_lock_version: version.reload.lock_version
    ).call
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      terms: {
        first_second_fare: "1624.00", additional_fare: "406.00", single_supplement: "1624.00",
        nccf: "320.00", first_second_discount: "150.00", additional_discount: "37.50", taxes_fees: "137.00"
      },
      commission: { method: "not_provided" }, stage: "estimate",
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: version.id,
        use_tentative_draft: true, arrangement_lock_version: version.reload.lock_version,
        arrangement_item_id: item.id, supplier_resource_ids: [ ocean.id ]
      }
    ).call

    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement)
    click_link "Edit terms"
    click_link "Start from Supplier terms"
    assert_text "Review Supplier copy"
    assert_field "Cruise fare first", with: "1624.00"
    fill_in "Cruise fare first", with: "1700.00"
    click_button "Save Client terms"
    assert_text "Client terms created."
    click_link "Edit terms"
    assert_field "Cruise fare first", with: "1700.00"
    assert_text "Unchanged"
  end

  test "celebrity double preview subtracts the discount" do
    arrangement, _version, _item, _ocean = connected_double
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit")
    fill_in "Cruise fare first", with: "1624.00"
    fill_in "Cruise fare second", with: "1624.00"
    fill_in "NCCF first", with: "320.00"
    fill_in "NCCF second", with: "320.00"
    fill_in "Taxes and fees first", with: "137.00"
    fill_in "Taxes and fees second", with: "137.00"
    fill_in "Discount first", with: "150.00"
    fill_in "Discount second", with: "150.00"
    click_button "Preview"
    assert_text "$3,862.00"
    assert_no_text "$4,462.00"
  end

  test "a category without occupancy stays advanced" do
    arrangement, _version, _item, _ocean = cruise_with
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: arrangement.versions.sole.id,
        use_tentative_draft: true, arrangement_lock_version: arrangement.versions.sole.lock_version,
        arrangement_item_id: arrangement.arrangement_items.sole.id, supplier_resource_ids: [ arrangement.supplier_resources.sole.id ]
      }
    ).call
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit")
    assert_text "Confirm occupancy"
    assert_no_selector "#cruise-client-terms-form"
  end

  test "invalid save preserves the entered fare" do
    arrangement, _version, _item, _ocean = connected_double
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit")
    fill_in "Cruise fare first", with: "not-a-price"
    fill_in "Cruise fare second", with: "10.00"
    click_button "Save Client terms"
    assert_selector "#form-error-summary"
    assert_field "Cruise fare first", with: "not-a-price"
  end

  test "single occupancy shows a single column and not double review" do
    arrangement, version, item, ocean = cruise_with
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      expected_cabins: { single: 1 }, version_lock_version: version.reload.lock_version
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: version.id,
        use_tentative_draft: true, arrangement_lock_version: version.reload.lock_version,
        arrangement_item_id: item.id, supplier_resource_ids: [ ocean.id ]
      }
    ).call
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit")
    assert_selector "th", text: "Single"
    assert_no_selector "th", text: "1st"
    assert_text "Double is unavailable"
    assert_text "Triple is unavailable"
  end

  test "removing the source link keeps the client amount" do
    arrangement, version, item, ocean = cruise_with
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      expected_cabins: { double: 1 }, version_lock_version: version.reload.lock_version
    ).call
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      terms: { first_second_fare: "1624.00", nccf: "320.00", taxes_fees: "137.00" },
      commission: { method: "not_provided" }, stage: "estimate",
      version_lock_version: version.reload.lock_version, idempotency_key: SecureRandom.uuid
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: version.id,
        use_tentative_draft: true, arrangement_lock_version: version.reload.lock_version,
        arrangement_item_id: item.id, supplier_resource_ids: [ ocean.id ]
      }
    ).call
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_client_terms_path(@departure, arrangement, editor: "edit", copy: "review")
    click_button "Save Client terms"
    click_link "Edit terms"
    choose "Remove source link", match: :first
    click_button "Save Client terms"
    click_link "Edit terms"
    assert_field "Cruise fare first", with: "1624.00"
    assert_no_text "Unchanged"
  end

  private

  def connected_double
    arrangement, version, item, ocean = cruise_with
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency, actor: @staff, arrangement: arrangement, resource: ocean,
      expected_cabins: { double: 1 }, version_lock_version: version.reload.lock_version
    ).call
    ConnectCruiseServiceOffer.new(
      agency: @agency, actor: @staff, arrangement: arrangement, idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new", title: "Celebrity Beyond sailing", supplier_arrangement_version_id: version.id,
        use_tentative_draft: true, arrangement_lock_version: version.reload.lock_version,
        arrangement_item_id: item.id, supplier_resource_ids: [ ocean.id ]
      }
    ).call
    [ arrangement, version, item, ocean ]
  end

  def cruise_with
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
