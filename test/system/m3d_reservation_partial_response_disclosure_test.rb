# frozen_string_literal: true

require "application_system_test_case"

class M3dReservationPartialResponseDisclosureTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Disclosure Supplier")
    @departure = create_capacity_departure(@agency, name: "Disclosure Departure")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Disclosure",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)

    @reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: @version.id,
        scopes: [
          { target_kind: "arrangement", label: "Whole Arrangement" },
          {
            target_kind: "item",
            arrangement_item_id: @graph[:item].id,
            label: "Item scope"
          }
        ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @staff, reservation: @reservation,
      attributes: {
        channel: "portal",
        reference_note: "Portal request",
        occurred_at: Time.current
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end

  test "partial response disclosure shows confirmation only for included confirmed scopes" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_reservation_path(@departure, @arrangement, @reservation)
    click_link "Record Supplier response"

    assert_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true
    assert_field "Confirmed without identifier reason"

    select "Declined", from: "Outcome for all pending scopes"
    assert_no_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true
    assert_no_field "Confirmed without identifier reason"

    select "Counterproposed", from: "Outcome for all pending scopes"
    assert_no_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true

    select "Partial / mixed outcomes", from: "Response coverage"
    assert_selector "[data-reservation-response-fields-target='partialPanel']", visible: true

    # Defaults leave scopes included and confirmed — confirmation panel remains.
    assert_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true

    within("[data-reservation-response-fields-target='partialPanel']") do
      all("select[data-outcome-kind]").each { |select| select.select "Declined" }
    end
    assert_no_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true

    within("[data-reservation-response-fields-target='partialPanel']") do
      all("select[data-outcome-kind]").each { |select| select.select "Counterproposed" }
    end
    assert_no_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true

    within(all("[data-reservation-response-fields-target='scopeOutcome']").last) do
      select "Confirmed", from: "Outcome"
    end
    assert_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true

    # Excluding a default-confirmed scope must hide confirmation when no included confirmed remain.
    within("[data-reservation-response-fields-target='partialPanel']") do
      all("select[data-outcome-kind]").each { |select| select.select "Confirmed" }
      all("input[type='checkbox'][name='scope_ids[]']").each { |box| box.uncheck }
    end
    assert_no_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true
    assert page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("[data-reservation-response-fields-target='confirmationPanel']")
        if (!panel) return false
        return Array.from(panel.querySelectorAll("input, select, textarea"))
          .every((input) => input.disabled)
      })()
    JS

    within(all("[data-reservation-response-fields-target='partialPanel'] [data-reservation-response-fields-target='scopeOutcome']").first) do
      check "Include this scope"
      select "Confirmed", from: "Outcome"
    end
    assert_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true
    assert_field "Confirmed without identifier reason"

    select "All pending scopes", from: "Response coverage"
    select "Confirmed", from: "Outcome for all pending scopes"
    assert_selector "[data-reservation-response-fields-target='confirmationPanel']", visible: true
  end
end
