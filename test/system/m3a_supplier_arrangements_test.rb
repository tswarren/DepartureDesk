require "application_system_test_case"

class M3ASupplierArrangementsTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @supplier = create_supplier("System Hotel").record
    @provider = create_supplier("System DMC").record
    @contact = @supplier.contacts.create!(
      agency: @agency,
      first_name: "Casey",
      last_name: "Planner",
      status: "active"
    )
    @departure = create_complete_draft("System M3A Draft")
  end

  test "staff creates an arrangement graph from the departure and abandons it" do
    sign_in_from_browser(@staff)

    visit departure_path(@departure)
    assert_selector "h1.dd-page-title", exact_text: "System M3A Draft"
    within "nav[aria-label='Composition areas']" do
      click_link "Suppliers"
    end
    click_link "Supplier planning"
    click_link "Add arrangement"

    assert_selector "h1.dd-page-title", exact_text: "New arrangement"
    fill_in "Name", with: "System Hotel Block"
    select supplier_option_text(@supplier), from: "Contracting supplier"
    select supplier_contact_option_text(@contact), from: "Arrangement contact"
    click_button "Save arrangement"

    assert_text "Arrangement saved."
    assert_selector "h1.dd-page-title", exact_text: "System Hotel Block"
    click_link "Add item", match: :first

    assert_selector "h1.dd-page-title", exact_text: "Set up item"
    fill_in "Name", with: "Rooms"
    select "Lodging", from: "Category"
    select supplier_option_text(@provider), from: "Default service provider"
    check "Add first occurrence"
    within(:xpath, "//article[.//h2[normalize-space()='First occurrence']]") do
      fill_in "Name", with: "Check in"
      fill_in_html_date "Start date", "2026-10-01"
      fill_in_html_date "End date", "2026-10-01"
      select "America/New_York", from: "Time zone"
    end
    check "Add first resource"
    within(:xpath, "//article[.//h2[normalize-space()='First resource']]") do
      fill_in "Name", with: "Room block"
      fill_in "Description", with: "Twenty rooms"
    end
    click_button "Save item setup"

    assert_text "Item setup saved."
    assert_text "Rooms"
    assert_text "Check in"
    assert_text "Room block"

    visit abandon_departure_arrangement_path(@departure, @departure.supplier_arrangements.find_by!(name: "System Hotel Block"))
    assert_selector "h1.dd-page-title", exact_text: "Abandon arrangement"
    fill_in "Reason", with: "Supplier withdrew tentative space"
    click_button "Abandon arrangement"

    assert_text "Arrangement abandoned."
    assert_text "Abandoned"
  end

  test "viewer can read supplier planning without mutation actions" do
    arrangement = create_arrangement("Viewer System Arrangement")
    item = create_item(arrangement, "Viewer Rooms").record
    create_occurrence(item, "Viewer Check in")
    create_resource(item, "Viewer Room block")

    sign_in_from_browser(@viewer)

    visit departure_path(@departure)
    assert_text "Viewer System Arrangement"
    assert_no_text "Add arrangement"
    click_link "Viewer System Arrangement"

    assert_selector "h1.dd-page-title", exact_text: "Viewer System Arrangement"
    assert_text "Viewer Rooms"
    assert_text "Viewer Check in"
    assert_text "Viewer Room block"
    assert_no_text "Edit arrangement"
    assert_no_text "Add item"
    assert_no_text "Add occurrence"
    assert_no_text "Add resource"
    assert_no_text "Remove"
  end

  test "guided item setup preserves selected sections and focuses validation summary" do
    arrangement = create_arrangement("Validation Setup Arrangement")
    sign_in_from_browser(@staff)

    visit departure_arrangement_new_item_setup_path(@departure, arrangement)
    fill_in "Name", with: "Rooms needing correction"
    select "Lodging", from: "Category"
    check "Add first occurrence"
    within(:xpath, "//article[.//h2[normalize-space()='First occurrence']]") do
      fill_in "Name", with: "Invalid stay"
      fill_in_html_date "Start date", "2026-10-08"
      fill_in_html_date "End date", "2026-10-01"
      select "America/New_York", from: "Time zone"
    end
    check "Add first resource"
    within(:xpath, "//article[.//h2[normalize-space()='First resource']]") do
      fill_in "Name", with: "Room block"
    end
    click_button "Save item setup"

    assert_selector "#form-error-summary"
    assert_equal "form-error-summary", page.evaluate_script("document.activeElement.id")
    assert_field "Name", with: "Rooms needing correction", match: :first
    assert_checked_field "Add first occurrence"
    assert_checked_field "Add first resource"
    assert_text "First occurrence: End date must be on or after the start date"
  end

  test "staff cannot force supplier inactivation when arrangement dependencies exist" do
    create_arrangement("Staff Dependency Arrangement")

    sign_in_from_browser(@staff)
    visit supplier_path(@supplier)
    click_link "Change status"

    assert_selector "h1.dd-page-title", exact_text: "Change supplier status"
    assert_text "Current Supplier planning dependencies block ordinary inactivation."
    assert_text "Staff Dependency Arrangement"
    assert_no_text "Force inactivation over current Supplier planning dependencies"
    assert_no_field "Force reason"
  end

  private

  def create_arrangement(name)
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: name, contracting_supplier_id: @supplier.id, supplier_contact_id: @contact.id }
    ).call.record
  end

  def create_item(arrangement, name)
    version = arrangement.versions.first.reload
    CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: name, category: "lodging", default_service_provider_id: @provider.id }
    ).call
  end

  def create_occurrence(item, name)
    version = item.supplier_arrangement.versions.first.reload
    CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: name, starts_on: "2026-10-01", ends_on: "2026-10-01", time_zone: "America/New_York" }
    ).call
  end

  def create_resource(item, name)
    version = item.supplier_arrangement.versions.first.reload
    CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: name }
    ).call
  end

  def create_supplier(display_name)
    CreateSupplier.new(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: display_name },
      categories: [ "lodging" ]
    ).call
  end

  def create_complete_draft(name)
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: name,
        starts_on: Date.new(2026, 10, 1),
        ends_on: Date.new(2026, 10, 8),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  def supplier_option_text(supplier)
    "#{supplier.display_name_for_directory} · #{supplier.supplier_reference}"
  end

  def supplier_contact_option_text(contact)
    "#{contact.supplier.display_name_for_directory} · #{contact.display_name_for_directory}"
  end
end
