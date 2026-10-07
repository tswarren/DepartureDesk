# frozen_string_literal: true

require "application_system_test_case"

class TransportationSupplierCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @admin, kind: "organization",
      names: { display_name: "ABC Motorcoach" },
      categories: [ "ground_transportation" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @staff,
      attributes: {
        name: "Smith Family Reunion",
        starts_on: Date.new(2027, 11, 3),
        ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @staff.id
      },
      current_office: @office
    ).call.record
  end

  test "staff operates the ABC charter from composition through a successor" do
    sign_in_from_browser(@staff)
    visit suppliers_departure_composition_path(@departure)
    click_link "Add transportation"
    fill_in "Arrangement name", with: "ABC Motorcoach"
    find("#arrangement_contracting_supplier_id option[value='#{@supplier.id}']").select_option
    click_button "Open Transportation Agreement"
    assert_text "Transportation Agreement"

    add_segment(
      name: "Hotel → Port", date: "2027-11-06", time: "10:00",
      origin: "Hilton Fort Lauderdale Marina", destination: "Port Everglades",
      rate: "200", final_count: "2027-11-03"
    )
    add_segment(
      name: "Port → Airport", date: "2027-11-13", time: "09:30",
      origin: "Port Everglades", destination: "Fort Lauderdale-Hollywood International Airport",
      rate: "175", final_count: "2027-11-10"
    )

    assert_no_text "Airport → Port"
    assert_text "Hilton Fort Lauderdale Marina → Port Everglades"
    assert_text "15 passenger spaces"
    assert_text "Up to 2 additional motorcoaches on request"
    assert_text "Maximum 45 passengers"
    assert_text "$200.00"
    assert_text "$175.00"

    fill_in_html_date "Amount due date", "2027-11-03"
    click_button "Save charter amount due"
    assert_text "Hotel → Port · $200.00"
    assert_text "Port → Airport · $175.00"
    assert_selector "#charter-amount-due", text: "$375.00"

    fill_in "Reference note", with: "ABC confirmed the charter"
    fill_in "Confirmed without a Supplier identifier because", with: "No file number yet"
    click_button "Confirm Transportation agreement"
    assert_text "Supplier confirmed"
    assert_text "Cancellation terms — Needs clarification"

    segment = ArrangementItemDefinition.find_by!(agency: @agency, name: "Hotel → Port").arrangement_item
    visit edit_departure_arrangement_transportation_segment_path(@departure, segment.supplier_arrangement, segment)
    click_button "Save segment"
    assert_text "immutable after Supplier confirmation"

    ActivateDeparture.new(
      agency: @agency, actor: @staff, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    visit departure_arrangement_transportation_path(@departure, segment.supplier_arrangement)
    click_button "Activate Transportation agreement"
    assert_text "Transportation agreement activated"

    select "Hotel → Port", from: "Segment"
    select "Confirm another motorcoach", from: "Change"
    fill_in_html_date "Effective date", Time.find_zone!("America/New_York").today.iso8601
    fill_in "Reference note", with: "Second coach"
    click_button "Record coach change"
    assert_text "2 motorcoaches confirmed"
    assert_text "30 passenger spaces"
    assert_text "Up to 1 additional motorcoach on request"
    assert_text "Maximum 45 passengers"
    assert_text "$400.00"
    assert_text "$575.00"

    select "Release a motorcoach", from: "Change"
    fill_in_html_date "Effective date", Time.find_zone!("America/New_York").today.iso8601
    fill_in "Reference note", with: "Released the extra coach"
    click_button "Record coach change"
    assert_no_text "2 motorcoaches confirmed"
    assert_text "1 motorcoach confirmed"
    assert_text "Financial effect of a released motorcoach — Needs clarification"
    assert_selector "#charter-amount-due", text: "$575.00"

    click_button "Record final count received"
    assert_text "Final passenger and luggage count recorded"
    assert_selector "#charter-amount-due", text: "$575.00"

    travel_to Time.find_zone!("America/New_York").local(2027, 11, 7, 12, 0) do
      visit departure_arrangement_transportation_path(@departure, segment.supplier_arrangement)
      select "Hotel → Port", from: "Segment"
      select "Confirm another motorcoach", from: "Change"
      fill_in_html_date "Effective date", "2027-11-06"
      fill_in "Reference note", with: "Coach after the due date"
      click_button "Record coach change"
      assert_text "Payment treatment for a motorcoach confirmed after Nov 3"
      assert_selector "#charter-amount-due", text: "$575.00"
      assert_text "Maximum 45 passengers"

      select "Port → Airport", from: "Segment"
      select "Confirm another motorcoach", from: "Change"
      fill_in_html_date "Effective date", "2027-11-02"
      fill_in "Reference note", with: "Backdated Port coach"
      click_button "Record coach change"
      assert_text "Port → Airport · $350.00"
      assert_text "Hotel → Port · $400.00"
    end

    click_button "Create successor for a contractual change"
    assert_text "Successor draft created"
    successor = @departure.supplier_arrangements.find_by!(name: "ABC Motorcoach").versions.find_by!(status: "draft")
    governing = @departure.supplier_arrangements.find_by!(name: "ABC Motorcoach").governing_version
    assert_equal governing.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id),
      successor.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
    assert_equal 20_000, governing.supplier_cost_components.joins(:supplier_cost_definition).find_by!(amount_minor_units: 20_000).amount_minor_units

    using_session(:viewer) do
      sign_in_from_browser(agency_users(:harbor_viewer))
      visit departure_arrangement_transportation_path(@departure, segment.supplier_arrangement)
      assert_text "Transportation Agreement"
      assert_no_button "Save segment"
      assert_no_button "Confirm Transportation agreement"
    end

    using_session(:cove) do
      sign_in_from_browser(agency_users(:cove_admin), password: "cove-password1")
      visit departure_arrangement_transportation_path(@departure, segment.supplier_arrangement)
      assert_text(/RecordNotFound|doesn't exist|Not Found/i)
    end
  end

  private

  def add_segment(name:, date:, time:, origin:, destination:, rate:, final_count:)
    click_link "Add segment"
    fill_in "Segment name", with: name
    fill_in "Pickup", with: origin
    fill_in "Drop-off", with: destination
    fill_in_html_date "Service date", date
    find("#segment_starts_at_local").execute_script("this.value = arguments[0]", time)
    fill_in "Passenger capacity per motorcoach", with: "15"
    fill_in "Confirmed motorcoaches", with: "1"
    fill_in "Additional motorcoaches available on request", with: "2"
    fill_in "Supplier rate per motorcoach", with: rate
    fill_in_html_date "Final passenger and luggage count due", final_count
    click_button "Save segment"
    assert_text name
  end
end
