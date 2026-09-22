# frozen_string_literal: true

require "test_helper"

class M4d0rBuilderRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    @contractor = create_capacity_supplier(@agency, "Builder Contractor")
    @departure = create_capacity_departure(@agency, name: "Builder Remediation Trip")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Builder"
    )
  end

  test "save for later reaches empty workspace and save and add components reaches first form" do
    sign_in_as @staff

    post departures_path, params: {
      commit: "Save for later",
      departure: {
        name: "Later Concept",
        timing_mode: "target",
        target_timing_text: "Spring 2027",
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @staff.id
      }
    }
    later = @agency.departures.find_by!(name: "Later Concept")
    assert_redirected_to departure_builder_path(later)
    follow_redirect!
    assert_match "Your departure concept is saved", response.body
    assert_select "a", text: "Add the first component"
    assert_select "a", text: "Supplier planning"
    assert_select "a", text: "Client offers"
    assert_select "form[action=?]", departure_builder_components_path(later), count: 0

    post departures_path, params: {
      commit: "Save and add components",
      departure: {
        name: "Immediate Concept",
        timing_mode: "unknown",
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @staff.id
      }
    }
    immediate = @agency.departures.find_by!(name: "Immediate Concept")
    assert_redirected_to new_departure_builder_component_path(immediate)
    follow_redirect!
    assert_select "h1.dd-page-title", text: "Add the first component"
    assert_select "input#component_name", count: 1
  end

  test "manage_departures show redirects to builder while viewer keeps show" do
    sign_in_as @staff
    get departure_path(@departure)
    assert_redirected_to departure_builder_path(@departure)

    sign_in_as @viewer
    get departure_path(@departure)
    assert_response :success
    assert_select "h1.dd-page-title", text: @departure.name
    get departure_builder_path(@departure)
    assert_response :not_found
  end

  test "first component creates package atomically and failure re-renders" do
    sign_in_as @staff

    post departure_builder_components_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      package_decision: "yes",
      name: "",
      package_name: @departure.name,
      placement: "included"
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "input[name=package_decision][value=yes][checked]"

    assert_difference -> { @departure.packages.count }, 1 do
      assert_difference -> { @departure.service_offers.count }, 1 do
        post departure_builder_components_path(@departure), params: {
          idempotency_key: SecureRandom.uuid,
          package_decision: "yes",
          name: "Coach transfer",
          client_timing_text: "Day 1 morning",
          package_name: "Main trip",
          placement: "included",
          return_intent: "workspace"
        }
      end
    end
    package = @departure.packages.find_by!(name: "Main trip")
    assert_redirected_to departure_builder_path(@departure, package_id: package.id)
    follow_redirect!
    assert_match "Coach transfer", response.body
    assert_select "form[action=?]", departure_builder_components_path(@departure), count: 0
    assert_select "a", text: "Decide how provided"
  end

  test "supplier bind preserves service offer identity" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Coach", placement: "included" }
    ).call.record
    offer = package.editable_draft_version.inclusions.first.service_offer
    original_id = offer.id
    version = offer.editable_draft_version

    get fulfillment_departure_builder_component_path(@departure, offer)
    assert_response :success
    assert_match "Decide how", response.body

    post fulfillment_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: version.lock_version,
      fulfillment_basis: "supplier_supported"
    }
    assert_redirected_to sources_departure_builder_component_path(@departure, offer)

    source_key = [
      @graph[:arrangement].id,
      @graph[:version].id,
      @graph[:item].id,
      @graph[:occurrence].id,
      @graph[:resource].id,
      nil,
      "1"
    ].join(":")

    assert_no_difference -> { @departure.service_offers.count } do
      post sources_departure_builder_component_path(@departure, offer), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: version.reload.lock_version,
        source_key: source_key,
        membership_kind: "required"
      }
    end
    assert_redirected_to departure_builder_path(@departure, work_on: "supplier")
    offer.reload
    assert_equal original_id, offer.id
    assert offer.editable_draft_version.definition.m3_backed?
    assert offer.editable_draft_version.source_bindings.exists?
  end

  test "pricing shows pending rather than zero and preview hides internal codes" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: {
        package_name: "Trip",
        component_name: "Coach",
        placement: "included",
        client_timing_text: "Day 1"
      }
    ).call.record

    get departure_builder_path(@departure, work_on: "pricing", package_id: package.id)
    assert_response :success
    assert_match(/Pending/i, response.body)
    refute_match(/\b\$0(\.00)?\b/, response.body)
    refute_match(/0\.00/, response.body)

    get departure_builder_path(@departure, work_on: "preview", package_id: package.id)
    assert_response :success
    assert_match "Internal preview — not shared with Clients", response.body
    refute_match(/undecided|m3_backed|fulfillment_basis|lock_version|margin/i, response.body)
    assert_match "Coach", response.body
  end

  test "multi-package requires explicit selection and never falls back" do
    sign_in_as @staff
    first = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "First", component_name: "A", placement: "included" }
    ).call.record
    CreatePackageDraft.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Second" }
    ).call

    get departure_builder_path(@departure)
    assert_response :success
    assert_match "Choose which Package you are working on", response.body
    assert_select "select#builder-package option[value=?]", first.id
    assert_select "#itinerary-heading", count: 0

    workspace = DepartureBuilderWorkspace.new(
      agency: @agency, departure: @departure.reload, require_explicit_package: true
    )
    assert workspace.package_selection_required?
    assert_nil workspace.selected_package

    get departure_builder_path(@departure, package_id: "00000000-0000-7000-8000-000000000099")
    assert_response :success
    assert_match "Choose which Package you are working on", response.body
    workspace = DepartureBuilderWorkspace.new(
      agency: @agency,
      departure: @departure,
      package_id: "00000000-0000-7000-8000-000000000099",
      require_explicit_package: true
    )
    assert workspace.package_selection_invalid?
    assert_nil workspace.selected_package

    get departure_builder_path(@departure, package_id: first.id)
    assert_response :success
    assert_select "#itinerary-heading"
    assert_match "First", response.body
  end

  test "cruise helper writes nothing on open and only submitted names on save" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Cabin", placement: "included" }
    ).call.record
    offer = package.editable_draft_version.inclusions.first.service_offer

    get cruise_setup_departure_builder_component_path(@departure, offer)
    assert_response :success
    assert_equal 0, offer.editable_draft_version.choice_groups.count

    post cruise_setup_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      option_names: [ "", "  " ]
    }
    assert_response :unprocessable_entity
    assert_equal 0, offer.editable_draft_version.reload.choice_groups.count

    post cruise_setup_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      option_names: [ "Interior", "Ocean view" ]
    }
    assert_redirected_to departure_builder_path(@departure)
    group = offer.editable_draft_version.reload.choice_groups.sole
    assert_equal "Cabin category", group.name
    assert_equal [ "Interior", "Ocean view" ], group.service_offer_choice_options.order(:position).map(&:name)
  end

  test "recommendation prefers work_on outcome and skips early publication noise" do
    CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Main", component_name: "Coach", placement: "included" }
    ).call

    readiness = EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure.reload).call
    general = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness
    ).call
    refute_equal :departure_not_active, general.finding.code
    refute_equal "Ready to publish", general.finding.group

    supplier = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness, work_on: "supplier"
    ).call
    assert_equal "Supplier support", supplier.finding.group
    assert_equal :fulfillment_departure_builder_component, supplier.path_helper.to_sym
  end
end
