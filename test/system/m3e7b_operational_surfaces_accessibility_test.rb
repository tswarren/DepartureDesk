# frozen_string_literal: true

require "application_system_test_case"

class M3e7bOperationalSurfacesAccessibilityTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @graph = build_operational_graph!
  end

  test "deposit and Deadline create forms recover keyboard focus through error summary" do
    sign_in_from_browser(@staff)

    visit new_departure_arrangement_version_deposit_path(
      @graph[:departure], @graph[:arrangement], @graph[:version]
    )
    wait_for_turbo
    find_button("Save deposit requirement").send_keys(:return)
    wait_for_turbo
    assert_selector "#form-error-summary"
    assert_equal "form-error-summary",
      page.evaluate_script("document.activeElement && document.activeElement.id")
    within("#form-error-summary") { find("a", match: :first).send_keys(:return) }
    focused = page.evaluate_script("document.activeElement && document.activeElement.id")
    assert focused.present?
    assert_match(/supplier_deposit_requirement_definition|amount|currency|rule/i, focused)

    visit new_departure_arrangement_version_deadline_path(
      @graph[:departure], @graph[:arrangement], @graph[:version]
    )
    wait_for_turbo
    find("input[type=submit], button[type=submit]", match: :first).send_keys(:return)
    wait_for_turbo
    assert_selector "#form-error-summary"
    assert_equal "form-error-summary",
      page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  test "exposure and ending surfaces retain context without overflow at required viewports" do
    activate_operational_graph!
    sign_in_from_browser(@staff)

    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window width, 900

      visit departure_arrangement_exposure_path(@graph[:departure], @graph[:arrangement])
      wait_for_turbo
      assert_text "Qualified Supplier exposure"
      assert_no_page_overflow

      visit end_departure_arrangement_path(@graph[:departure], @graph[:arrangement])
      wait_for_turbo
      assert_text "End arrangement"
      assert_text(/Blockers|Cascades/i)
      assert_no_page_overflow

      visit departure_arrangement_version_deposits_path(
        @graph[:departure], @graph[:arrangement], @graph[:version]
      )
      wait_for_turbo
      assert_text(/Deposit/i)
      assert_no_page_overflow

      visit departure_arrangement_version_deadlines_path(
        @graph[:departure], @graph[:arrangement], @graph[:version]
      )
      wait_for_turbo
      assert_text(/Deadline/i)
      assert_no_page_overflow
    end
  end

  test "ending preview refresh with invalid reason focuses form error summary" do
    activate_operational_graph!
    sign_in_from_browser(@staff)
    visit end_departure_arrangement_path(@graph[:departure], @graph[:arrangement])
    wait_for_turbo
    assert_text "End arrangement"

    select "Other", from: "Reason"
    find_button("Refresh preview").send_keys(:return)
    wait_for_turbo
    assert_selector "#form-error-summary"
    assert_equal "form-error-summary",
      page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  private

  def build_operational_graph!
    supplier = create_capacity_supplier(@agency, "M3E.7b UI Supplier")
    departure = create_capacity_departure(@agency, name: "M3E.7b UI Departure", status: "draft")
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix: "M3E7bUI", capacity_management: "unmanaged"
    ).merge(supplier:, departure:)
    SupplierCostSource.create!(
      agency: @agency, departure:,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      charging_supplier: supplier,
      label: "UI zero cost", position: 1
    ).tap do |source|
      SupplierCostDefinition.create!(
        agency: @agency, departure:,
        supplier_arrangement: graph[:arrangement],
        supplier_arrangement_version: graph[:version],
        supplier_cost_source: source,
        stage: "contracted", status: "forecast_ready", mode: "zero_cost",
        zero_cost_reason: "Included", currency: "USD",
        forecast_ready_by: @staff, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:m3e7b-ui",
        readiness_provenance: "Signed"
      )
    end
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure:,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      committed_supplier: supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
    graph
  end

  def activate_operational_graph!
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @staff, arrangement: @graph[:arrangement],
      version: @graph[:version].reload,
      arrangement_lock_version: @graph[:arrangement].reload.lock_version,
      version_lock_version: @graph[:version].lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Approved",
        confirmed_without_identifier_reason: "Later"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
    @graph[:arrangement].reload
    @graph[:version].reload
  end
end
