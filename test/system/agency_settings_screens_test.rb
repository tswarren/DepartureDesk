require "application_system_test_case"

# Slice 1 step 1 screens: S-02 Agency profile and S-03 Users and permissions,
# at desktop width and 375px (first-slice UI acceptance).
class AgencySettingsScreensTest < ApplicationSystemTestCase
  setup do
    @scenario = M1DirectoryScenario.empty
    @admin = @scenario.actor
    @staff = @scenario.baseline_staff
  end

  teardown do
    M1DirectoryScenario.cleanup!(@scenario.agency)
  end

  test "S-02: an agency admin edits the profile, previews a footer and changes what a document shows" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    open_administration
    assert_text "Client documents can't be generated yet"
    assert_text "Enter the agency contact email."

    click_link_and_expect "Edit profile", heading: "Edit agency profile", css: ".dd-page-actions a"
    fill_in "Contact email", with: "desk@example.test"
    fill_in "Phone number", with: "202-555-0123"
    fill_in "Seller-of-travel disclosure", with: "CST 1234567-40\nRegistration does not constitute approval."
    fill_in "Confirmation footer", with: "Thanks for **sailing** with us."
    within(find_field("Confirmation footer").ancestor(".dd-field-group")) do
      click_button "Preview"
      within(".dd-info-callout") { assert_selector "strong", text: "sailing" }
    end
    check "Seller-of-travel disclosure on receipts"
    uncheck "Phone on confirmations"
    fill_in "Client hold duration (days)", with: "3"
    click_button "Save profile"

    assert_text "Agency profile updated."
    assert_no_text "Client documents can't be generated yet"
    assert_text "desk@example.test"
    assert_text "Registration does not constitute approval."
    assert_selector "strong", text: "sailing"
    assert_text "3 days"
    receipt = @scenario.agency.document_inclusions.find_by!(document_family: "receipt")
    assert receipt.include_seller_of_travel_disclosure
    assert_not @scenario.agency.document_inclusions.find_by!(document_family: "confirmation").include_phone
  end

  test "S-02: invalid values show the error summary and keep what was typed" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    visit edit_administration_agency_path
    wait_for_turbo
    fill_in "Phone number", with: "123"
    fill_in "Agency contact name", with: "Robin Reyes"
    click_button "Save profile"

    assert_selector "#form-error-summary:focus"
    within("#form-error-summary") { click_link "Phone number is not a valid number for the phone country" }
    assert_equal "agency_phone_number", page.evaluate_script("document.activeElement.id")
    assert_equal "true", find_field("Phone number")["aria-invalid"]
    assert_field "Agency contact name", with: "Robin Reyes"
  end

  test "S-02: leaving the profile form with unsaved changes asks first" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    visit edit_administration_agency_path
    wait_for_turbo
    fill_in "Agency contact name", with: "Unsaved"
    dismiss_confirm { click_link "Cancel" }
    assert_selector "h1.dd-page-title", exact_text: "Edit agency profile"
  end

  test "S-02: traveler types are added, reordered, renamed and inactivated" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    open_administration
    within("#traveler-types") do
      assert_equal [ "Adult", "Child", "Child 0–4" ], all("tbody th").map(&:text)
      fill_in "New traveler type", with: "Senior"
      click_button "Add traveler type"
    end
    assert_text "Traveler type added."
    within("#traveler-types") do
      within("tr", text: "Senior") { click_button "Move up" }
      assert_selector "tbody tr:nth-child(3) th", exact_text: "Senior"
      assert_equal [ "Adult", "Child", "Senior", "Child 0–4" ], all("tbody th").map(&:text)
      within("tr", text: /\AChild\b(?! 0)/) { click_button "Inactivate" }
    end
    within("#traveler-types") { assert_selector "tr", text: /Child\s+Inactive/ }
    within("#traveler-types tr", text: "Senior") { click_link "Edit" }
    fill_in "Name", with: "Senior 65+"
    check "Counts as an adult"
    click_button "Save traveler type"
    within("#traveler-types tr", text: "Senior 65+") { assert_text "Counts as an adult" }
  end

  test "S-03: an agency admin grants a staff user a permission" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    visit administration_agency_users_path
    wait_for_turbo
    within("tr", text: @staff.display_name) { assert_text "Baseline only" }
    within("tr", text: @admin.display_name) { assert_text "All" }

    visit administration_agency_user_path(@staff)
    wait_for_turbo
    click_link_and_expect "Edit permissions", heading: "Permissions for #{@staff.display_name}"
    check "Financial records"
    click_button "Save permissions"

    assert_text "Permissions updated."
    within(".dd-list-item", text: "Financial records") { assert_text "Held" }
    within(".dd-list-item", text: "Departure management") { assert_text "Not held" }
    assert_equal [ "financial_records" ], @staff.reload.granted_permissions

    visit administration_agency_user_path(@admin)
    wait_for_turbo
    assert_text "An Agency Admin holds every permission"
    assert_no_link "Edit permissions"
  end

  test "S-02 and S-03 reflow at 375px without page overflow" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      [ administration_agency_path, edit_administration_agency_path, administration_agency_users_path,
        administration_agency_user_path(@staff), edit_administration_agency_user_permissions_path(@staff) ].each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_selector "nav[aria-label='Breadcrumb']"
        assert_no_page_overflow
        page.save_screenshot(Rails.root.join("tmp/screenshots/step1_#{width}_#{path.parameterize}.png").to_s) if ENV["STEP1_SCREENSHOTS"]
      end
    end
  end
end
