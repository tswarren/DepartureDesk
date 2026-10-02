# frozen_string_literal: true

require "test_helper"

class HotelAgreementsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Hilton", category: "lodging"
    )
    @arrangement = @graph[:arrangement]
    @item = @graph[:item]
    @version = @graph[:version]
  end

  test "staff open the agreement for a lodging item" do
    sign_in_as @staff

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, @arrangement, @item)

    assert_response :success
    assert_select "h2", text: "Hotel Agreement"
    assert_select "#hotel-agreement-role", text: "Draft"
    assert_select "#hotel-term-destination_fee", text: /Not recorded/
    assert_select "a", text: "Advanced Supplier planning"
    assert_select "button", text: "Create successor draft", count: 0
  end

  test "a non-lodging item is not found" do
    @graph[:item_definition].update!(category: "activity_attraction")
    sign_in_as @staff

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, @arrangement, @item)

    assert_response :not_found
  end

  test "another agency cannot open the agreement" do
    sign_in_as agency_users(:cove_admin)

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, @arrangement, @item)

    assert_response :not_found
  end

  test "a viewer can read and cannot add a deposit" do
    sign_in_as @viewer

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, @arrangement, @item)
    assert_response :success
    assert_select "a", text: "Add deposit", count: 0

    get new_item_hotel_agreement_deposit_departure_arrangement_hotel_path(@departure, @arrangement, @item)
    assert_redirected_to root_path
  end

  test "an explicit version cannot leave the arrangement" do
    other = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor,
      provider: @contractor, prefix: "Other"
    )
    sign_in_as @staff

    get item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, version_id: other[:version].id
    )

    assert_response :not_found
  end

  test "saving a stay opened from the agreement returns there" do
    sign_in_as @staff
    post departure_composition_suppliers_hotels_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      arrangement: { contracting_supplier_id: @contractor.id },
      item: { name: "Pre-cruise hotel stay" },
      occurrence: {
        starts_on: "2027-11-04",
        ends_on: "2027-11-06",
        starts_at_local: "15:00",
        ends_at_local: "12:00",
        time_zone: "America/New_York"
      }
    }
    item = ArrangementItemDefinition.joins(:supplier_arrangement_version).find_by!(
      agency: @agency, name: "Pre-cruise hotel stay",
      supplier_arrangement_versions: { status: "draft" }
    ).arrangement_item
    arrangement = item.supplier_arrangement
    stay = arrangement.editable_version.service_occurrence_definitions.find_by!(arrangement_item: item, name: "Stay")

    patch item_stay_departure_arrangement_hotel_path(@departure, arrangement, item), params: {
      return_to: "hotel_agreement",
      definition_lock_version: stay.lock_version,
      occurrence: {
        starts_on: "2027-11-04",
        ends_on: "2027-11-06",
        starts_at_local: "16:00",
        ends_at_local: "11:00",
        time_zone: "America/New_York"
      }
    }

    assert_redirected_to item_hotel_agreement_departure_arrangement_hotel_path(@departure, arrangement, item)
  end

  test "staff record item coverage for a deposit and see it on the schedule" do
    sign_in_as @staff

    get new_item_hotel_agreement_deposit_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, version_id: @version.id
    )
    assert_response :success
    assert_select "label", text: "Amount"
    assert_select "label", text: /coverage/, count: 0

    post item_hotel_agreement_deposits_departure_arrangement_hotel_path(@departure, @arrangement, @item), params: {
      version_id: @version.id,
      idempotency_key: SecureRandom.uuid,
      amount: "415.60",
      due_on: "2026-10-01"
    }

    assert_redirected_to item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, version_id: @version.id
    )
    follow_redirect!
    assert_match "$415.60", response.body
    assert_match "October 1, 2026", response.body
    definition = @version.supplier_deposit_requirement_definitions.sole
    assert_equal [ @item.id ], definition.supplier_deposit_requirement_definition_coverage_links.map(&:arrangement_item_id)
  end

  test "staff record a stay-scoped term and see shared source defaults" do
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: @staff, arrangement_item: @item, scope: "stay", kind: "destination_fee",
      governing_wording: "The $150 destination fee is waived.",
      source_description: "Hilton agreement", supplier_reference: "G-100",
      idempotency_key: SecureRandom.uuid
    ).call
    sign_in_as @staff

    get new_item_hotel_agreement_term_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, "cancellation", version_id: @version.id
    )

    assert_response :success
    assert_select "input[name='source_description'][value='Hilton agreement']"
    assert_select "input[name='supplier_reference'][value='G-100']"
    assert_select "legend", text: "Scope"

    post item_hotel_agreement_terms_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, "cancellation"
    ), params: {
      version_id: @version.id,
      idempotency_key: SecureRandom.uuid,
      scope: "stay",
      governing_wording: "Cancellation follows the Hotel's governing provision.",
      source_description: "A different letter",
      supplier_reference: "G-200"
    }

    assert_redirected_to item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, version_id: @version.id
    )
    follow_redirect!
    assert_select "#hotel-term-cancellation", text: /Cancellation follows the Hotel's governing provision/
    fee = @version.supplier_agreement_references.find_by!(kind: "destination_fee")
    assert_equal "Hilton agreement", fee.source_description
    assert_equal "G-100", fee.supplier_reference
  end

  test "a viewer can read term wording and cannot open the editor" do
    RecordSupplierAgreementReference.new(
      agency: @agency, actor: agency_users(:harbor_admin), arrangement_item: @item, kind: "attrition",
      governing_wording: "November 4 minimum 7.",
      source_description: "Hilton agreement", idempotency_key: SecureRandom.uuid
    ).call
    sign_in_as @viewer

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, @arrangement, @item)

    assert_response :success
    assert_match "November 4 minimum 7.", response.body
    assert_select "a", text: "Add term", count: 0

    get new_item_hotel_agreement_term_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, "cancellation"
    )

    assert_redirected_to root_path
  end

  test "editing a thin deposit preserves description, currency, and time zone" do
    sign_in_as @staff
    post item_hotel_agreement_deposits_departure_arrangement_hotel_path(@departure, @arrangement, @item), params: {
      version_id: @version.id,
      idempotency_key: SecureRandom.uuid,
      amount: "415.60",
      due_on: "2026-10-01"
    }
    definition = @version.supplier_deposit_requirement_definitions.sole
    definition.update!(description: "Group deposit note", time_zone: "America/Chicago")

    patch item_hotel_agreement_deposit_departure_arrangement_hotel_path(@departure, @arrangement, @item, definition), params: {
      version_id: @version.id,
      lock_version: definition.lock_version,
      amount: "500.00",
      due_on: "2027-05-07"
    }

    assert_redirected_to item_hotel_agreement_departure_arrangement_hotel_path(
      @departure, @arrangement, @item, version_id: @version.id
    )
    definition.reload
    assert_equal "Group deposit note", definition.description
    assert_equal "USD", definition.currency
    assert_equal "America/Chicago", definition.time_zone
    assert_equal 50_000, definition.fixed_amount_minor_units
    assert_equal "2027-05-07", definition.rule_parameters["date"]

    definition.update!(currency: "EUR")
    patch item_hotel_agreement_deposit_departure_arrangement_hotel_path(@departure, @arrangement, @item, definition), params: {
      version_id: @version.id,
      lock_version: definition.lock_version,
      amount: "10.00",
      due_on: "2027-05-07"
    }

    assert_response :not_found
    definition.reload
    assert_equal "EUR", definition.currency
    assert_equal "Group deposit note", definition.description
    assert_equal 50_000, definition.fixed_amount_minor_units
  end
end
