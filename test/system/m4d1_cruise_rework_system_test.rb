# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseReworkSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: provider.id },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @pool = cabin.record.pool
    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin block"
    )
  end

  test "staff confirms the agreement and records contracted rates from the cruise workspace" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)

    fill_in "Supplier group number", with: "1119999"
    fill_in "Contract date", with: "2026-09-13"
    fill_in "agreement_group_creation_date_confirm", with: "2026-09-13"
    click_on "Confirm Supplier agreement"
    assert_text "Cruise agreement recorded."
    assert_text "Group 1119999"

    visit departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    fill_in "Base Fare · First/Second", with: "1624.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"
    assert_text "Supplier rates saved"
    click_on "Record contracted rates"
    assert_text "Contracted rates recorded. The estimate is unchanged."
    click_on "Estimate"
    assert_field "Base Fare · First/Second", with: "1624.00"

    visit departure_arrangement_activation_path(@departure, @arrangement)
    assert_text "Cabin O1 needs ready contracted Supplier rates."
    assert_no_text "Confirm the Cruise supplier agreement before activation."
  end

  test "staff activates the original agreement, records the same-terms increase, and activates the supplemental successor" do
    prepare_ready_original!
    sign_in_from_browser(@staff)

    visit departure_arrangement_activation_path(@departure, @arrangement)
    assert_text "Ready for activation."
    select "Supplier confirmation", from: "Evidence kind"
    fill_in "Evidence date", with: Date.current.iso8601
    fill_in "Channel", with: "portal"
    fill_in "Safe reference note", with: "Supplier approved exact terms"
    fill_in "Confirmed without identifier reason", with: "Supplier did not issue one"
    check "I confirm the entered cost-source list is complete."
    check "I acknowledge these listed provisional estimate sources." if page.has_text?("Provisional estimates")
    check "I confirm known confirmation-triggered commitments are covered by the listed triggers."
    click_on "Activate arrangement"
    assert_text "Arrangement activated."

    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    fill_in "Additional cabins", with: "4"
    fill_in "Deposit per additional cabin (USD)", with: "50.00"
    fill_in "Evidence date", with: Date.current.iso8601
    fill_in "Evidence note", with: "Supplier added four O1 cabins"
    click_on "Record same-terms increase"
    assert_text "Same-terms capacity increase recorded."
    requirement = SupplierArrangementCruiseCapacityDepositRequirement.order(:created_at).last
    assert_equal 20_000, requirement.amount_minor_units

    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    fill_in "Maximum occupancy", with: "3"
    fill_in "Opening quantity", with: "4"
    click_on "Add supplemental O1 block"
    assert_text "Supplemental O1 block added on a new successor."
    assert_text "Supplemental O1 block"

    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    successor = @arrangement.versions.find_by!(status: "draft")
    assert_equal @version.id, @arrangement.reload.governing_version_id
    fill_in "Supplier group number", with: "1119999"
    fill_in "agreement_group_creation_date_confirm", with: "2026-09-13"
    fill_in "Contract date", with: "2026-10-20"
    fill_in "Deposit treatment for a supplemental block", with: "No additional initial deposit for this block."
    click_on "Confirm Supplier agreement"
    assert_text "Cruise agreement recorded."

    visit departure_arrangement_activation_path(@departure, @arrangement)
    assert_text "Cabin O1 needs ready contracted Supplier rates."
    satisfy_cruise_activation_gate!(agency: @agency, actor: @staff, arrangement: @arrangement, version: successor.reload)
    successor.capacity_pool_definitions.where(evidence_reference_note: nil).find_each do |definition|
      definition.update!(
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed supplemental block"
      )
    end
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: successor,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Supplemental cabins",
      fixed_quantity: 4,
      quantity_basis: "resource_units",
      position: 1
    ) unless successor.supplier_commitment_trigger_definitions.exists?

    visit departure_arrangement_activation_path(@departure, @arrangement)
    assert_text "Ready for activation."
    select "Supplier confirmation", from: "Evidence kind"
    fill_in "Evidence date", with: Date.current.iso8601
    fill_in "Channel", with: "portal"
    fill_in "Safe reference note", with: "Supplemental block confirmed"
    fill_in "Confirmed without identifier reason", with: "Supplier did not issue one"
    check "I confirm the entered cost-source list is complete."
    check "I acknowledge these listed provisional estimate sources." if page.has_text?("Provisional estimates")
    check "I confirm known confirmation-triggered commitments are covered by the listed triggers."
    click_on "Activate successor"
    assert_text "Arrangement activated."
    assert_equal successor.id, @arrangement.reload.governing_version_id
    assert @version.reload.superseded?
    assert_equal "1119999", @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true).group_reference
  end

  private

  def prepare_ready_original!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-09-13",
      group_creation_date: "2026-09-13"
    ).call
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version.reload,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )
  end
end
