require "application_system_test_case"

class M3CSupplierCostsSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    @supplier = create_supplier("System Cruise Line").record
    @departure = create_complete_draft("System M3C Costs")
    @arrangement = CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "System Cruise Block", contracting_supplier_id: @supplier.id }
    ).call.record
    @item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: @arrangement,
      version_lock_version: @arrangement.versions.find_by!(version_number: 1).lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { name: "Cabin inventory", category: "lodging" }
    ).call.record
  end

  test "staff configures a percentage component with a selected base through the item cost workspace" do
    sign_in_from_browser(@admin)
    visit departure_arrangement_item_costs_workspace_path(@departure, @arrangement, @item)

    assert_selector "h1.dd-page-title", exact_text: "Cabin inventory"
    find("summary", text: "Add cost source").click
    fill_in "Source label", with: "O1 terms"
    select supplier_option_text(@supplier), from: "Charging supplier"
    click_button "Add cost source"
    assert_text "Cost source saved."

    find("summary", text: "Add cost stage").click
    select "Contracted", from: "Stage"
    select "Calculated", from: "Mode"
    click_button "Add stage"
    assert_text "Cost stage saved."

    find("summary", text: "Add component").click
    fill_in "Label", with: "Fare"
    select "Supplier charge", from: "Economic role"
    select "Fixed", from: "Calculation"
    fill_in "Amount (USD)", with: "1000.00"
    click_button "Add component"
    assert_text "Cost component saved."
    assert_text "Fare"

    find("summary", text: "Add component").click
    fill_in "Label", with: "Commission"
    select "Expected commission", from: "Economic role"
    select "Percentage", from: "Calculation"
    fill_in "Percentage", with: "15"
    select "Additive", from: "Percentage treatment"
    select "Fare", from: "Base 1"
    click_button "Add component"
    assert_text "Cost component saved."
    assert_text "Commission"
    assert_text "bases add Fare"
  end

  private

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
        starts_on: Date.new(2027, 11, 6),
        ends_on: Date.new(2027, 11, 13),
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
end
