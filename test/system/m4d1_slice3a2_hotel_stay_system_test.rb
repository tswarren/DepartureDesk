# frozen_string_literal: true

require "application_system_test_case"

class M4d1Slice3a2HotelStaySystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(time_zone: "America/New_York")
  end

  test "staff records a hotel stay, nightly inventory, and leaves an unsupported pool unchanged" do
    sign_in_from_browser(@staff)
    visit suppliers_departure_composition_path(@departure)
    click_link_and_expect "Add Hotel stay", heading: @departure.name, path: new_departure_composition_suppliers_hotel_path(@departure)

    assert_selector "a.dd-skip-link[href='#main-content']", text: "Skip to main content", visible: :all
    assert_selector "main#main-content"
    assert_selector "h1", text: @departure.name
    [ 375, 768, 1280 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
      find("#item_name").click
      page.driver.browser.action.send_keys(:tab).perform
      assert_equal "occurrence_starts_on", page.evaluate_script("document.activeElement.id")
    end

    fill_in "Stay name", with: "Pre-cruise hotel stay"
    fill_in_html_date "Arrival date", "2027-11-04"
    fill_in_html_date "Departure date", "2027-11-03"
    find("#arrangement_contracting_supplier_id option[value='#{@contractor.id}']").select_option
    click_button "Save and continue"
    assert_selector "#form-error-summary"
    assert_equal "2027-11-03", find("#occurrence_ends_on").value

    fill_in_html_date "Departure date", "2027-11-06"
    click_button "Save and continue"
    assert_selector "#room-categories-heading"
    assert_text "Nov 4–6, 2027 · 2 nights"
    assert_no_text "Nov 1"
    assert_no_button "Add room night"

    fill_in "resource_name", with: "Standard"
    fill_in "resource_maximum_occupancy", with: "4"
    click_button "Add room category"
    assert_text "Standard"
    assert_text "Maximum occupancy 4"
    fill_in "resource_name", with: "Deluxe"
    fill_in "resource_maximum_occupancy", with: "4"
    click_button "Add room category"
    assert_text "Deluxe"

    item = ArrangementItemDefinition.find_by!(agency: @agency, name: "Pre-cruise hotel stay").arrangement_item
    assert_equal 1, draft_version(item).service_occurrence_definitions.where(arrangement_item: item).count

    openings = [
      [ "2027-11-04", "November 4", "Standard", "5" ],
      [ "2027-11-04", "November 4", "Deluxe", "2" ],
      [ "2027-11-05", "November 5", "Standard", "10" ],
      [ "2027-11-05", "November 5", "Deluxe", "5" ]
    ]
    openings.each do |date, night_name, resource_name, quantity|
      resource = resource_named(item, resource_name)
      target = "#{date}--#{resource.supplier_resource_id}"
      fill_in "opening_quantity_#{target}", with: quantity
      select "Contract", from: "opening_evidence_kind_#{target}"
      find("#opening_evidence_on_#{target}").execute_script("this.value = arguments[0]", "2026-09-30")
      fill_in "opening_evidence_note_#{target}", with: "Hilton group contract"
      within("#hotel-cell-#{date}-#{resource.supplier_resource_id}") { click_button "Save contracted rooms" }
      assert_text "#{night_name} #{resource_name} saved."
    end

    assert_equal 3, draft_version(item).service_occurrence_definitions.where(arrangement_item: item).count
    assert_equal 6, draft_version(item).capacity_pair_definitions.where(arrangement_item: item).count
    assert_equal 4, draft_version(item).capacity_pool_definitions.count

    find("#hotel-step-overview").click
    assert_text "Standard / 15 contracted room nights"
    assert_text "Deluxe / 7 contracted room nights"
    assert_text "2 room categories · 22 contracted room nights"
    assert_no_text "Supplier rates"
    assert_no_text "Review & activate"

    visit item_inventory_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item)
    standard = pool_named(item, "November 4", "Standard")
    fill_in "opening_quantity_#{standard.id}", with: "6"
    within("#hotel-cell-2027-11-04-#{standard.supplier_resource_id}") { click_button "Save contracted rooms" }
    assert_text "November 4 Standard saved."
    assert_equal [ 6, 2, 10, 5 ], opening_quantities(item)

    visit edit_item_stay_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item)
    [ 375, 768, 1280 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
      assert_selector "label[for='occurrence_starts_on']", text: "Arrival date"
    end

    visit item_inventory_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item)
    [ 375, 768, 1280 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
      assert_selector "h1", text: @departure.name
      assert_selector "#hotel-setup-nav"
    end

    pool = pool_named(item, "November 4", "Standard")
    pool.update!(unit_label: "cabins")
    visit item_inventory_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item)
    assert_text "A room night Pool is not one numeric block measured in rooms."
    assert_link "Item capacity"
    assert_equal "cabins", pool.reload.unit_label
    assert_equal 6, pool.proposed_opening_quantity
  end

  private

  def draft_version(item)
    item.supplier_arrangement.versions.find_by!(status: "draft")
  end

  def occurrence_named(item, name)
    draft_version(item).service_occurrence_definitions.find_by!(arrangement_item: item, name: name)
  end

  def resource_named(item, name)
    draft_version(item).supplier_resource_definitions.find_by!(arrangement_item: item, name: name)
  end

  def opening_quantities(item)
    version = draft_version(item)
    nights = version.service_occurrence_definitions.where(arrangement_item: item).where.not(name: "Stay").order(:starts_on, :id)
    resources = version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id)
    nights.flat_map do |night|
      resources.map do |resource|
        version.capacity_pool_definitions.find_by!(
          service_occurrence_id: night.service_occurrence_id,
          supplier_resource_id: resource.supplier_resource_id
        ).proposed_opening_quantity
      end
    end
  end

  def pool_named(item, night_name, resource_name)
    night = occurrence_named(item, night_name)
    resource = resource_named(item, resource_name)
    draft_version(item).capacity_pool_definitions.find_by!(
      service_occurrence_id: night.service_occurrence_id,
      supplier_resource_id: resource.supplier_resource_id
    )
  end
end
