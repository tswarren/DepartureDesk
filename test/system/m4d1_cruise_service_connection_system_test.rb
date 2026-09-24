# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseServiceConnectionSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
  end

  test "staff connects one cabin category" do
    arrangement, _version, _item, _ocean = cruise_with("O1" => "Prime Oceanview")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    assert_selector "h1.dd-page-title", exact_text: "Connect Cruise service"
    fill_in "Client title", with: "Celebrity Beyond sailing"
    click_button "Create and connect service"
    assert_selector "h1.dd-page-title", exact_text: "Cruise service connection"
    assert_text "Connected"
    assert_text "Ready for category pricing"
    assert_text "O1 — Prime Oceanview"
    assert_no_text "cruise_cabin:"
    assert_no_text "choice_gated"
  end

  test "staff connects two cabin categories" do
    arrangement, = cruise_with("O1" => "Prime Oceanview", "I1" => "Inside")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Two categories"
    click_button "Create and connect service"
    assert_text "Connected"
    assert_text "O1 — Prime Oceanview"
    assert_text "I1 — Inside"
    assert_equal 1, ServiceOffer.where(departure: @departure).count
  end

  test "editing a connection keeps the cabin choice identity" do
    arrangement, = cruise_with("O1" => "Prime Oceanview")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Celebrity Beyond sailing"
    click_button "Create and connect service"
    assert_selector "h1.dd-page-title", exact_text: "Cruise service connection"
    offer = ServiceOffer.find_by!(name: "Celebrity Beyond sailing")
    option_id = offer.editable_draft_version.choice_options.sole.id
    click_link "Edit Cruise service connection"
    assert_selector "h1.dd-page-title", exact_text: "Edit Cruise service connection"
    fill_in "Client title", with: "Celebrity Beyond sailing updated"
    click_button "Save connection"
    assert_text "Cruise service connection updated."
    assert_equal option_id, offer.reload.editable_draft_version.choice_options.sole.id
    assert_equal "Celebrity Beyond sailing", offer.name
  end

  test "staff adds and removes a cabin category without losing the retained choice" do
    arrangement, = cruise_with("O1" => "Prime Oceanview", "I1" => "Inside")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Both categories"
    uncheck "I1 — Inside"
    click_button "Create and connect service"
    assert_text "Connected"
    offer = ServiceOffer.find_by!(name: "Both categories")
    kept_id = offer.editable_draft_version.choice_options.sole.id
    click_link "Edit Cruise service connection"
    check "I1 — Inside"
    click_button "Save connection"
    assert_text "Cruise service connection updated."
    assert_equal 2, offer.reload.editable_draft_version.choice_options.count
    assert offer.editable_draft_version.choice_options.exists?(kept_id)
    click_link "Edit Cruise service connection"
    uncheck "I1 — Inside"
    click_button "Save connection"
    assert_text "Cruise service connection updated."
    assert_equal [ kept_id ], offer.reload.editable_draft_version.choice_options.pluck(:id)
  end

  test "staff connects an existing undecided outline" do
    arrangement, = cruise_with("O1" => "Prime Oceanview")
    CreateServiceOfferOutline.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Existing outline", client_timing_text: "Day 1 embarkation" }
    ).call
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Client sailing"
    select "Existing outline", from: "Existing service outline"
    click_button "Connect existing service"
    assert_text "Connected"
    offer = ServiceOffer.find_by!(name: "Existing outline")
    assert_equal "Client sailing", offer.editable_draft_version.definition.client_title
    assert_equal "Day 1 embarkation", offer.editable_draft_version.definition.client_timing_text
    assert_equal "Existing outline", offer.name
  end

  test "staff decides later and then resumes the same service" do
    arrangement, = cruise_with("O1" => "Prime Oceanview")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Smith sailing"
    click_button "Save for later"
    assert_text "Decide later"
    assert_text "Smith sailing"
    click_link "Connect Cruise service"
    check "O1 — Prime Oceanview"
    click_button "Connect existing service"
    assert_text "Connected"
    assert_equal 1, ServiceOffer.where(departure: @departure, name: "Smith sailing").count
    assert_equal 1, ServiceOffer.find_by!(name: "Smith sailing").editable_draft_version.choice_options.count
  end

  test "an advanced graph stays unchanged" do
    arrangement, = cruise_with("O1" => "Prime Oceanview")
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
    fill_in "Client title", with: "Celebrity Beyond sailing"
    click_button "Create and connect service"
    assert_text "Connected"
    offer = ServiceOffer.find_by!(name: "Celebrity Beyond sailing")
    option = offer.editable_draft_version.choice_options.sole
    option.update!(price_effect_minor_units: 2_500)
    visit departure_arrangement_cruise_service_connection_path(@departure, arrangement)
    assert_text "Advanced"
    assert_no_button "Save connection"
    assert_equal 2_500, option.reload.price_effect_minor_units
    assert_equal "cruise_cabin:#{option.id}", option.client_rate_category_key
  end

  test "the editor is reachable by keyboard at narrow and desktop widths" do
    arrangement, = cruise_with("O1" => "Prime Oceanview")
    sign_in_from_browser(@staff)
    [ 375, 1400 ].each do |width|
      resize_window width, 900
      visit departure_arrangement_cruise_service_connection_path(@departure, arrangement, editor: "connect", sailing: "draft")
      assert_selector "h1.dd-page-title", exact_text: "Connect Cruise service"
      field = find_field("Client title")
      field.send_keys(:tab)
      assert_selector "fieldset"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("document.documentElement.clientWidth") + 1
    end
  end

  private

  def cruise_with(cabins)
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency, actor: @staff, departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Western Caribbean", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    resources = cabins.map do |code, name|
      CreateCruiseCabinCategorySetup.new(
        agency: @agency, actor: @staff, arrangement: arrangement,
        resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
        pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
        version_lock_version: version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call.record.resource
    end
    [ arrangement, version.reload, sailing.record.item, *resources ]
  end
end
