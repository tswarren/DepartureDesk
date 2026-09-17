require "application_system_test_case"

class M3D0PlanningWorkspaceTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M3D.0 proof departure")
    @supplier = create_capacity_supplier(@agency, "Hilton planning supplier")
    @provider = create_capacity_supplier(@agency, "Hilton service provider")
  end

  test "Celebrity guided setup supports keyboard submission and error-summary recovery" do
    arrangement = create_arrangement("Celebrity guided setup")
    sign_in_from_browser(@staff)
    visit departure_arrangement_new_item_setup_path(@departure, arrangement)

    fill_in "Name", with: "Celebrity O1 cabins", match: :first
    select "Lodging", from: "Category"
    find_field("Add first occurrence").send_keys(:space)
    within(:xpath, "//article[.//h2[normalize-space()='First occurrence']]") do
      fill_in "Name", with: "Celebrity sailing"
      fill_in_html_date "Start date", "2026-06-08"
      fill_in_html_date "End date", "2026-06-01"
    end
    find_field("Add first resource").send_keys(:space)
    within(:xpath, "//article[.//h2[normalize-space()='First resource']]") do
      fill_in "Name", with: "O1 cabin"
    end
    find_button("Save item setup").send_keys(:return)
    wait_for_turbo

    assert_selector "#form-error-summary"
    assert_equal "form-error-summary",
      page.evaluate_script("document.activeElement && document.activeElement.id")
    assert_text "First occurrence: End date must be on or after the start date"
    within("#form-error-summary") { find("a", match: :first).send_keys(:return) }
    assert_equal "service_occurrence_definition_ends_on",
      page.evaluate_script("document.activeElement && document.activeElement.id")

    within(:xpath, "//article[.//h2[normalize-space()='First occurrence']]") do
      fill_in_html_date "End date", "2026-06-08"
    end
    find_button("Save item setup").send_keys(:return)
    wait_for_turbo

    assert_text "Item setup saved."
    assert_text "Celebrity O1 cabins"
    assert_text "Celebrity sailing"
    assert_text "O1 cabin"
  end

  test "Hilton flow continues through capacity cost setup and review" do
    arrangement = create_arrangement("Hilton compressed workflow")
    sign_in_from_browser(@staff)
    visit departure_arrangement_path(@departure, arrangement)

    activate "Add the first Item"
    fill_in "Name", with: "Hilton rooms", match: :first
    select "Lodging", from: "Category"
    find_field("Add first occurrence").send_keys(:space)
    within(:xpath, "//article[.//h2[normalize-space()='First occurrence']]") do
      fill_in "Name", with: "Hilton stay"
      fill_in_html_date "Start date", "2026-06-01"
      fill_in_html_date "End date", "2026-06-08"
    end
    find_field("Add first resource").send_keys(:space)
    within(:xpath, "//article[.//h2[normalize-space()='First resource']]") do
      fill_in "Name", with: "Room block"
    end
    find_button("Save item setup").send_keys(:return)
    wait_for_turbo

    within("#next-actions") { activate "Decide capacity for Hilton rooms" }
    choose "Managed capacity"
    find_button("Save applicability").send_keys(:return)
    wait_for_turbo
    check "Review Room block"
    find("select[aria-label='Decision for Hilton stay and Room block']").select("Not applicable")
    find_button("Save reviewed decisions").send_keys(:return)
    wait_for_turbo

    activate "Back to arrangement"
    activate "Add an Item cost for Hilton rooms"
    fill_in "What is this cost for?", with: "Hilton room terms"
    select "Contracted term", from: "Term stage"
    select "Zero cost", from: "Known cost"
    fill_in "Why is this known to be zero?", with: "Included in the Supplier package"
    find_button("Save and review cost").send_keys(:return)
    wait_for_turbo

    assert_selector "h1.dd-page-title", exact_text: "Hilton room terms"
    assert_text "Supplier cost review"
    assert_text "Known zero"
    assert_text "Readiness attestation"
  end

  test "Vineyard profile and capacity retain context at required viewports" do
    graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @provider,
      prefix: "Vineyard"
    )
    sign_in_from_browser(@staff)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900
      visit departure_arrangement_path(@departure, graph[:arrangement])
      wait_for_turbo
      assert_text "Vineyard Arrangement"
      assert_text "Vineyard item"
      assert_text "Planning readiness"
      assert_no_page_overflow

      visit departure_arrangement_item_capacity_path(
        @departure, graph[:arrangement], graph[:item]
      )
      wait_for_turbo
      assert_text "Vineyard item"
      assert_text "Vineyard occurrence"
      assert_text "Vineyard resource"
      assert_no_page_overflow
    end
  end

  private

  def create_arrangement(name)
    arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: name
    )
    arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
    arrangement
  end
end
