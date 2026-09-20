# frozen_string_literal: true

require "application_system_test_case"

class M3f1TaskFlowAccessibilityTest < ApplicationSystemTestCase
  include CapacityGraphHelper
  include CapacityActivatedGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "M3F.1 Task Flow Supplier")
    @departure = create_capacity_departure(@agency, name: "M3F.1 Task Flow")
  end

  test "capacity consequence add remove and focus work at required viewports" do
    graph = build_activated_established_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      actor: @staff, prefix: "M3F1 Cap"
    )
    reservation = CreateSupplierReservation.new(
      agency: @agency, actor: @staff, arrangement: graph[:arrangement],
      attributes: {
        booking_supplier_id: @supplier.id,
        supplier_arrangement_version_id: graph[:version].id,
        scopes: [ { target_kind: "arrangement", label: "Whole" } ]
      },
      idempotency_key: SecureRandom.uuid
    ).call.record
    RecordSupplierReservationRequest.new(
      agency: @agency, actor: @staff, reservation: reservation,
      attributes: { channel: "email", reference_note: "Sent" },
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_from_browser(@staff)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900
      visit departure_arrangement_reservation_path(
        @departure, graph[:arrangement], reservation, composer: "respond"
      )
      wait_for_turbo

      assert_text "Capacity consequences"
      assert_selector "[data-capacity-row]", count: 1
      assert_no_page_overflow

      find_button("Add capacity consequence").send_keys(:return)
      find_button("Add capacity consequence").send_keys(:return)
      assert_selector "[data-capacity-row]", count: 3
      labels = all("[data-capacity-row] button[data-action='reservation-response-fields#removeCapacity']")
        .map { |button| button["aria-label"] }
      assert_equal [
        "Remove capacity consequence 1",
        "Remove capacity consequence 2",
        "Remove capacity consequence 3"
      ], labels

      # Remove the middle row; remaining aria-labels must renumber.
      within(all("[data-capacity-row]")[1]) { find_button("Remove").send_keys(:return) }
      assert_selector "[data-capacity-row]", count: 2
      labels = all("[data-capacity-row] button[data-action='reservation-response-fields#removeCapacity']")
        .map { |button| button["aria-label"] }
      assert_equal [
        "Remove capacity consequence 1",
        "Remove capacity consequence 2"
      ], labels

      within(all("[data-capacity-row]").first) { find_button("Remove").send_keys(:return) }
      assert_selector "[data-capacity-row]", count: 1
      assert_equal "Remove capacity consequence 1",
        find("[data-capacity-row] button[data-action='reservation-response-fields#removeCapacity']")["aria-label"]
      focused_id = page.evaluate_script("document.activeElement && document.activeElement.id")
      assert_match(/capacity_consequences_0_/, focused_id.to_s)
    end
  end

  test "occupancy profile editors stay exclusive at required viewports" do
    graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: "M3F1 Occ", capacity_management: "unmanaged"
    )
    item = graph[:item]
    version = graph[:version]
    category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @staff, arrangement_item: item,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Adult" }
    ).call.record
    assumption = CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @staff, arrangement_item: item,
      idempotency_key: SecureRandom.uuid, attributes: {}
    ).call.record
    CreateSupplierCostOccupancyProfile.new(
      agency: @agency, actor: @staff, assumption: assumption,
      assumption_lock_version: assumption.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Single", resource_unit_count: 1 },
      positions: [ category.id ]
    ).call.record
    assumption.reload
    CreateSupplierCostOccupancyProfile.new(
      agency: @agency, actor: @staff, assumption: assumption,
      assumption_lock_version: assumption.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Double", resource_unit_count: 1 },
      positions: [ category.id, category.id ]
    ).call.record

    sign_in_from_browser(@staff)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900
      visit departure_arrangement_item_costs_workspace_path(
        @departure, graph[:arrangement], item
      )
      wait_for_turbo

      assert_text "Single"
      assert_text "Double"
      assert_selector "details[name^='occupancy-profile-']", minimum: 2
      assert_no_page_overflow

      group_name = first("details[name^='occupancy-profile-']")["name"]
      open_selector = %(details[name="#{group_name}"][open])

      first_edit = all("summary", text: "Edit occupancy profile")[0]
      scroll_to(first_edit, align: :center)
      first_edit.click
      assert_selector open_selector, count: 1

      # Re-query after DOM/open-state changes; opening another must close the first.
      second_edit = all("summary", text: "Edit occupancy profile")[1]
      scroll_to(second_edit, align: :center)
      second_edit.click
      assert_selector open_selector, count: 1
      assert_equal "Edit occupancy profile", find(open_selector).find("summary").text.strip
    end
  end
end
