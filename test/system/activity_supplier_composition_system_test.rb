# frozen_string_literal: true

require "application_system_test_case"

class ActivitySupplierCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @office = offices(:harbor_main)
    @agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
    @supplier = CreateSupplier.new(
      agency: @agency, actor: @staff, kind: "organization",
      names: { display_name: "Port Promotions" },
      categories: [ "activity_attraction" ]
    ).call.record
    @departure = CreateDeparture.new(
      agency: @agency, actor: @staff,
      attributes: {
        name: "Smith Family Reunion", starts_on: Date.new(2027, 11, 6), ends_on: Date.new(2027, 11, 13),
        time_zone: "America/New_York", operating_currency: "USD",
        responsible_office_id: @office.id, responsible_agency_user_id: @staff.id
      },
      current_office: @office
    ).call.record
  end

  test "staff operates island sightseeing from composition through a successor" do
    sign_in_from_browser(@staff)
    visit suppliers_departure_composition_path(@departure)
    click_link "Add activity"
    fill_in "Arrangement name", with: "Port Promotions"
    find("#arrangement_contracting_supplier_id option[value='#{@supplier.id}']").select_option
    click_button "Open Activity Agreement"
    assert_text "Activity Agreement"
    assert_no_link "Open advanced Arrangement"

    fill_activity(prefix: "activity", name: "Island Sightseeing")
    assert_text "Activity saved."
    assert_text "Nov 8, 2027"
    assert_text "9:30 am"
    assert_text "3:00 PM"
    assert_text "Location: CocoCay, Bahamas"
    assert_text "Meeting point: Not provided"
    assert_text "40 participant spaces"
    assert_text "Participant occupancy is not the group size."
    assert_text "$50.00 per confirmed participant"
    assert_text "4 → $200.00"
    assert_text "5 → $250.00"
    assert_text "20 → $1,000.00"
    assert_text "40 → $2,000.00"
    assert_text "Forecast illustration, not the payable quantity."
    assert_text "Current forecast for 4 illustrated participants: $200.00"
    assert_text "Gratuities are not included."
    assert_text "Minimum enrollment: 5 travelers"
    assert_text "Below minimum: Supplier decides whether to operate"
    assert_text "Review minimum enrollment Nov 1, 2027"
    assert_text "Final participant count due Nov 1, 2027"
    assert_text "Full payment due Nov 1, 2027"
    assert_text "Payment amount: Depends on confirmed participant count"
    assert_text "non-cancellable and non-refundable"

    item = activity_item("Island Sightseeing")
    version = draft_version
    assert_nil version.supplier_resource_definitions.find_by!(arrangement_item: item).maximum_occupancy
    assert_equal "America/Nassau", version.service_occurrence_definitions.find_by!(arrangement_item: item).time_zone
    assert_empty version.supplier_cost_components.where(calculation_kind: "minimum_quantity_shortfall")
    assert_empty version.supplier_amount_due_definitions
    assert_not version.supplier_deadline_definitions.exists?(deadline_type: "payment_due")
    payment = version.supplier_payment_requirement_definitions.find_by!(arrangement_item: item)
    assert_equal "authoritative_quantity_unavailable", payment.quantity_status
    assert_not payment.has_attribute?(:amount_minor_units)
    review = ActivityAgreementShape.deadline(version, item, "other")
    assert_equal "informational", review.kind
    assert_equal "Minimum-enrollment review", review.other_label
    assert version.supplier_agreement_references.exists?(arrangement_item: item, kind: "rate_inclusions")
    assert version.supplier_agreement_references.exists?(arrangement_item: item, kind: "cancellation")
    assert ActivityAgreementShape.deadline(version, item, "final_count_due")
    assert ActivityAgreementShape.deadline(version, item, "cancellation_cutoff")

    visit suppliers_departure_composition_path(@departure)
    assert_link "Open Activity Agreement"
    assert_no_link "Open advanced Arrangement"
    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)

    fill_activity(prefix: "new_activity", name: "Harbor sail")
    assert_text "Harbor sail"
    sibling = activity_item("Harbor sail")
    sibling_rate = component_amount(sibling)

    within "#activity-#{item.id}" do
      find("#activity_#{item.id}_ends_at_local").execute_script("this.value = arguments[0]", "08:00")
      click_button "Save activity"
    end
    assert_text "must be at or after the start time"
    assert_equal "Island Sightseeing", draft_version.arrangement_item_definitions.find_by!(arrangement_item: item).name
    assert_equal "15:00:00", draft_version.service_occurrence_definitions.find_by!(arrangement_item: item).ends_at_local.strftime("%H:%M:%S")
    assert_equal 40, draft_version.capacity_pool_definitions.find_by!(arrangement_item: sibling).proposed_opening_quantity
    assert_equal sibling_rate, component_amount(sibling)
    assert_equal 5, draft_version.supplier_operating_threshold_definitions.find_by!(arrangement_item: sibling).minimum_quantity
    assert draft_version.supplier_agreement_references.exists?(arrangement_item: sibling, kind: "rate_inclusions")

    unfinished = CreateArrangementItemSetup.new(
      agency: @agency, actor: @staff, arrangement: item.supplier_arrangement,
      version_lock_version: draft_version.lock_version, idempotency_key: SecureRandom.uuid,
      item_attributes: { name: "Unfinished", category: "activity_attraction", default_service_provider_id: @supplier.id }
    ).call.record.item
    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
    assert_text "Advanced Supplier planning · Add one activity occurrence."
    assert_no_button "Confirm Activity agreement"
    RemoveArrangementItem.new(
      agency: @agency, actor: @staff, item: unfinished, version_lock_version: draft_version.lock_version
    ).call

    lodging = CreateArrangementItemSetup.new(
      agency: @agency, actor: @staff, arrangement: item.supplier_arrangement,
      version_lock_version: draft_version.lock_version, idempotency_key: SecureRandom.uuid,
      item_attributes: { name: "Hotel night", category: "lodging", default_service_provider_id: @supplier.id }
    ).call.record.item
    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
    assert_text "Advanced Supplier planning"
    assert_no_button "Confirm Activity agreement"
    RemoveArrangementItem.new(
      agency: @agency, actor: @staff, item: lodging, version_lock_version: draft_version.lock_version
    ).call

    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
    fill_in "Reference note", with: "Port Promotions confirmed the activity"
    fill_in "Confirmed without a Supplier identifier because", with: "No file number yet"
    click_button "Confirm Activity agreement"
    assert_text "Supplier confirmed the Activity agreement."
    assert_no_button "Save activity"
    assert_raises(AgencyCommand::Error) do
      SaveActivity.new(
        agency: @agency, actor: @staff, departure: @departure, arrangement: item.supplier_arrangement, item: item,
        idempotency_key: SecureRandom.uuid,
        attributes: { name: "Changed after confirmation", location: "CocoCay, Bahamas", starts_on: "2027-11-08",
          starts_at_local: "09:30", ends_at_local: "15:00", time_zone: "America/Nassau", participant_spaces: 40,
          rate_amount: "50.00", expected_persons: 4, minimum_quantity: 5, terms_on: "2027-11-01" }
      ).call
    end

    ActivateDeparture.new(
      agency: @agency, actor: @staff, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
    click_button "Activate Activity agreement"
    assert_text "Activity agreement activated."
    assert_text "Governing"

    find("#arrangement_item_id").select("Island Sightseeing")
    select "Operate", from: "Supplier decision"
    fill_in "Observed participant quantity", with: "4"
    fill_in "Supplier evidence", with: "Port Promotions will operate with four travelers"
    fill_in_html_date "Decision date", "2027-11-01"
    click_button "Record Supplier decision"
    assert_text "Supplier confirmed activity will operate"
    assert_equal 5_000, component_amount(item)
    assert_equal Date.new(2027, 11, 8), governing_version.service_occurrence_definitions.find_by!(arrangement_item: item).starts_on
    assert item.service_occurrences.exists?

    find("#final_count_arrangement_item_id").select("Island Sightseeing")
    click_button "Record final participant count"
    assert_text "Final participant count recorded."
    assert_equal "2027-11-01", ActivityAgreementShape.deadline(governing_version, item, "final_count_due").rule_parameters["date"]

    click_button "Create successor for a contractual change"
    assert_text "Successor draft created. The activity identity is unchanged."
    assert_text "Proposed successor"
    successor = item.supplier_arrangement.versions.find_by!(status: "draft")
    assert_equal item.id, successor.arrangement_item_definitions.find_by!(name: "Island Sightseeing").arrangement_item_id
    assert_not SupplierConfirmation.exists?(supplier_arrangement_version_id: successor.id)
    assert_equal 5_000, governing_version.supplier_cost_components.pick(:amount_minor_units)
    visit departure_arrangement_activity_path(@departure, item.supplier_arrangement, version_id: governing_version.id)
    assert_text "Governing"
    assert_text "$50.00 per confirmed participant"

    using_session(:viewer) do
      sign_in_from_browser(agency_users(:harbor_viewer))
      visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
      assert_text "Activity Agreement"
      assert_no_button "Save activity"
      assert_no_button "Confirm Activity agreement"
      assert_no_button "Record Supplier decision"
    end

    using_session(:cove) do
      sign_in_from_browser(agency_users(:cove_admin), password: "cove-password1")
      visit departure_arrangement_activity_path(@departure, item.supplier_arrangement)
      assert_text(/RecordNotFound|doesn't exist|Not Found/i)
    end
  end

  test "a cancel outcome leaves the occurrence in place" do
    sign_in_from_browser(@staff)
    visit suppliers_departure_composition_path(@departure)
    click_link "Add activity"
    fill_in "Arrangement name", with: "Port Promotions"
    find("#arrangement_contracting_supplier_id option[value='#{@supplier.id}']").select_option
    click_button "Open Activity Agreement"
    fill_activity(prefix: "activity", name: "Island Sightseeing")
    fill_in "Reference note", with: "Port Promotions confirmed the activity"
    fill_in "Confirmed without a Supplier identifier because", with: "No file number yet"
    click_button "Confirm Activity agreement"
    ActivateDeparture.new(
      agency: @agency, actor: @staff, departure: @departure, lock_version: @departure.reload.lock_version
    ).call
    click_button "Activate Activity agreement"
    select "Cancel", from: "Supplier decision"
    fill_in "Observed participant quantity", with: "3"
    fill_in "Supplier evidence", with: "Port Promotions cancelled the activity"
    fill_in_html_date "Decision date", "2027-11-01"
    click_button "Record Supplier decision"
    assert_text "Supplier cancelled activity"
    assert_text "Nov 8, 2027"
    item = activity_item("Island Sightseeing")
    assert item.service_occurrences.exists?
    assert_equal Date.new(2027, 11, 8), governing_version.service_occurrence_definitions.find_by!(arrangement_item: item).starts_on
    assert_equal 5_000, component_amount(item)
    payment = governing_version.supplier_payment_requirement_definitions.find_by!(arrangement_item: item)
    assert_equal "authoritative_quantity_unavailable", payment.quantity_status
    assert_not payment.has_attribute?(:amount_minor_units)
  end

  private

  def fill_activity(prefix:, name:)
    find("##{prefix}_name").set(name)
    find("##{prefix}_location").set("CocoCay, Bahamas")
    find("##{prefix}_starts_on").execute_script("this.value = arguments[0]", "2027-11-08")
    find("##{prefix}_starts_at_local").execute_script("this.value = arguments[0]", "09:30")
    find("##{prefix}_ends_at_local").execute_script("this.value = arguments[0]", "15:00")
    find("##{prefix}_time_zone").set("America/Nassau")
    find("##{prefix}_participant_spaces").set("40")
    find("##{prefix}_rate_amount").set("50.00")
    find("##{prefix}_expected_persons").set("4")
    find("##{prefix}_minimum_quantity").set("5")
    find("##{prefix}_terms_on").execute_script("this.value = arguments[0]", "2027-11-01")
    find("##{prefix}_name").ancestor("form").click_button("Save activity")
  end

  def activity_item(name)
    ArrangementItemDefinition.find_by!(agency: @agency, name: name).arrangement_item
  end

  def draft_version
    @departure.supplier_arrangements.find_by!(name: "Port Promotions").versions.find_by!(status: "draft").reload
  end

  def governing_version
    @departure.supplier_arrangements.find_by!(name: "Port Promotions").reload.governing_version
  end

  def component_amount(item)
    version = item.supplier_arrangement.reload.governing_version || item.supplier_arrangement.versions.find_by!(status: "draft")
    version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
      .find_by!(supplier_cost_sources: { arrangement_item_id: item.id }).amount_minor_units
  end
end
