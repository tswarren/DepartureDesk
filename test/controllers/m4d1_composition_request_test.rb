# frozen_string_literal: true

require "test_helper"

class M4d1CompositionRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    @contractor = create_capacity_supplier(@agency, "Composition Contractor")
    @departure = create_capacity_departure(@agency, name: "Composition Trip")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @contractor, provider: @contractor, prefix: "Comp"
    )
  end

  test "save for later reaches overview chooser and save and add reaches Add Service" do
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
    assert_redirected_to departure_composition_path(later)
    follow_redirect!
    assert_match "What are you starting with?", response.body
    assert_select "a", text: "Add Service"
    assert_select "a", text: "Add Arrangement"
    assert_select "form[action=?]", departure_composition_services_path(later), count: 0

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
    assert_redirected_to new_departure_composition_service_path(immediate)
    follow_redirect!
    assert_select "h1.dd-page-title", text: "Add the first Service"
    assert_select "input#component_name", count: 1
  end

  test "manage_departures show redirects to composition while viewer keeps show" do
    sign_in_as @staff
    get departure_path(@departure)
    assert_redirected_to departure_composition_path(@departure)

    sign_in_as @viewer
    get departure_path(@departure)
    assert_response :success
    assert_select "h1.dd-page-title", text: @departure.name
    get departure_composition_path(@departure)
    assert_response :not_found
    get departure_builder_path(@departure)
    assert_response :not_found
  end

  test "builder work_on urls redirect with mapped outcome and package context" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Coach", placement: "included" }
    ).call.record

    get departure_builder_path(@departure, work_on: "preview", package_id: package.id)
    assert_redirected_to review_departure_composition_path(@departure, outcome: "proposal", package_id: package.id)

    get departure_builder_path(@departure, work_on: "supplier", package_id: package.id)
    assert_redirected_to suppliers_departure_composition_path(@departure, outcome: "supplier", package_id: package.id)

    get departure_builder_path(@departure, work_on: "pricing", package_id: package.id)
    assert_redirected_to package_departure_composition_path(@departure, outcome: "pricing", package_id: package.id)

    get departure_builder_path(@departure)
    assert_redirected_to departure_composition_path(@departure)
  end

  test "departed composition redirects to ordinary show" do
    sign_in_as @staff
    departed = CreateDeparture.new(
      agency: @agency,
      actor: @staff,
      attributes: {
        name: "Departed Composition Trip",
        starts_on: Date.current - 10,
        ends_on: Date.current - 3,
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @staff.id
      }
    ).call.record
    ActivateDeparture.new(
      agency: @agency, actor: @staff, departure: departed, lock_version: departed.lock_version
    ).call
    MarkDepartureDeparted.new(
      agency: @agency,
      departure: departed.reload,
      actor_kind: :agency_user,
      actor: @staff,
      lock_version: departed.lock_version
    ).call

    get departure_composition_path(departed)
    assert_redirected_to departure_path(departed)
  end

  test "cross-agency composition returns not found" do
    other = agencies(:cove)
    foreign = create_capacity_departure(other, name: "Foreign Trip")
    sign_in_as @staff
    get departure_composition_path(foreign)
    assert_response :not_found
  end

  test "Add Service creates package atomically and returns to Services" do
    sign_in_as @staff

    post departure_composition_services_path(@departure), params: {
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
        post departure_composition_services_path(@departure), params: {
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
    assert_redirected_to services_departure_composition_path(@departure, package_id: package.id)
    follow_redirect!
    assert_match "Coach transfer", response.body
    assert_select "nav[aria-label='Composition areas']"
    assert_select "#service-map-heading"
  end

  test "supplier bind returns to Services with closed return_to" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Coach", placement: "included" }
    ).call.record
    offer = package.editable_draft_version.inclusions.first.service_offer
    original_id = offer.id
    version = offer.editable_draft_version

    get fulfillment_departure_builder_component_path(@departure, offer, return_to: "services", outcome: "supplier", package_id: package.id)
    assert_response :success

    post fulfillment_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: version.lock_version,
      fulfillment_basis: "supplier_supported",
      return_to: "services",
      outcome: "supplier",
      package_id: package.id
    }
    assert_redirected_to sources_departure_builder_component_path(
      @departure, offer, return_to: "services", outcome: "supplier", package_id: package.id
    )

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
        membership_kind: "required",
        return_to: "services",
        outcome: "supplier",
        package_id: package.id
      }
    end
    assert_redirected_to services_departure_composition_path(@departure, outcome: "supplier", package_id: package.id)
    offer.reload
    assert_equal original_id, offer.id
    assert offer.editable_draft_version.definition.m3_backed?
  end

  test "arbitrary return_to is ignored and defaults safely" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Coach", placement: "included" }
    ).call.record
    offer = package.editable_draft_version.inclusions.first.service_offer

    post fulfillment_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      fulfillment_basis: "decide_later",
      return_to: "https://evil.example/phish"
    }
    assert_redirected_to services_departure_composition_path(@departure)
    refute_match(%r{https://evil}, response.redirect_url)
  end

  test "multi-package requires explicit selection and invalid package_id is not found" do
    sign_in_as @staff
    first = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "First", component_name: "A", placement: "included" }
    ).call.record
    CreatePackageDraft.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { name: "Second" }
    ).call

    get package_departure_composition_path(@departure)
    assert_response :success
    assert_match "Choose which Package you are working on", response.body

    workspace = DepartureBuilderWorkspace.new(
      agency: @agency, departure: @departure.reload, require_explicit_package: true
    )
    assert workspace.package_selection_required?
    assert_nil workspace.selected_package

    get package_departure_composition_path(@departure, package_id: "00000000-0000-7000-8000-000000000099")
    assert_response :not_found

    get package_departure_composition_path(@departure, package_id: first.id)
    assert_response :success
    assert_match "First", response.body
  end

  test "cruise helper returns to Services never builder show" do
    sign_in_as @staff
    package = CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Trip", component_name: "Cabin", placement: "included" }
    ).call.record
    offer = package.editable_draft_version.inclusions.first.service_offer

    get cruise_setup_departure_builder_component_path(@departure, offer, return_to: "services")
    assert_response :success
    assert_equal 0, offer.editable_draft_version.choice_groups.count

    post cruise_setup_departure_builder_component_path(@departure, offer), params: {
      version_lock_version: offer.editable_draft_version.lock_version,
      option_names: [ "Interior", "Ocean view" ],
      return_to: "services",
      package_id: package.id
    }
    assert_redirected_to services_departure_composition_path(@departure, package_id: package.id)
    group = offer.editable_draft_version.reload.choice_groups.sole
    assert_equal "Cabin category", group.name
    assert_equal [ "Interior", "Ocean view" ], group.service_offer_choice_options.order(:position).map(&:name)
  end

  test "second Service can create the first Package after an unassigned outline" do
    sign_in_as @staff

    post departure_composition_services_path(@departure), params: {
      idempotency_key: SecureRandom.uuid,
      package_decision: "no",
      name: "Standalone coach",
      client_timing_text: "Day 1",
      return_intent: "workspace"
    }
    assert_redirected_to services_departure_composition_path(@departure)
    assert_equal 1, @departure.service_offers.count
    assert_equal 0, @departure.packages.count

    assert_difference -> { @departure.packages.count }, 1 do
      assert_difference -> { @departure.service_offers.count }, 1 do
        post departure_composition_services_path(@departure), params: {
          idempotency_key: SecureRandom.uuid,
          package_decision: "yes",
          name: "Included dinner",
          client_timing_text: "Day 1 evening",
          package_name: "Main trip",
          placement: "included",
          return_intent: "workspace"
        }
      end
    end
    package = @departure.packages.find_by!(name: "Main trip")
    assert_redirected_to services_departure_composition_path(@departure, package_id: package.id)
    assert_equal 1, package.editable_draft_version.inclusions.count
    assert @departure.service_offers.find_by!(name: "Standalone coach").editable_draft_version.owning_package_version_id.nil?
  end

  test "recommendation uses applicability mapping and preview aliases to proposal" do
    CreateInitialPackageWithOutlineServiceOffer.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      attributes: { package_name: "Main", component_name: "Coach", placement: "included" }
    ).call

    readiness = EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure.reload).call
    undecided = readiness.findings.find { |finding| finding.code == :undecided_fulfillment }
    assert_equal "suppliers", undecided.affected_area
    assert_equal %w[supplier], undecided.applicable_outcomes
    assert undecided.applicable_to?("supplier")
    refute undecided.applicable_to?("publication")

    publish = readiness.findings.find { |finding| finding.code == :departure_not_active }
    assert_equal "review", publish.affected_area
    assert publish.applicable_to?("publication")
    refute publish.applicable_to?("supplier")
    refute publish.applicable_to?("preview")

    general = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness
    ).call
    refute_equal :departure_not_active, general.finding.code
    refute_equal "Ready to publish", general.finding.group

    supplier = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness, outcome: "supplier"
    ).call
    assert_equal "Supplier support", supplier.finding.group
    assert_equal :fulfillment_departure_builder_component, supplier.path_helper.to_sym

    aliased = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: @departure, readiness: readiness, work_on: "preview"
    ).call
    refute_equal "Ready to publish", aliased.finding.group

    ResolveServiceOfferFulfillmentBasis.new(
      agency: @agency,
      actor: @staff,
      offer: @departure.service_offers.sole,
      fulfillment_basis: "on_request",
      version_lock_version: @departure.service_offers.sole.editable_draft_version.lock_version
    ).call
    ready_supplier = RecommendDepartureBuilderAction.new(
      agency: @agency,
      departure: @departure.reload,
      readiness: EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call,
      outcome: "supplier"
    ).call
    assert_nil ready_supplier

    empty = create_capacity_departure(@agency, name: "Empty Publication Trip")
    empty_readiness = EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: empty).call
    no_components = empty_readiness.findings.find { |finding| finding.code == :no_components }
    assert no_components.applicable_to?("publication")
    publication = RecommendDepartureBuilderAction.new(
      agency: @agency, departure: empty, readiness: empty_readiness, outcome: "publication"
    ).call
    assert_equal :no_components, publication.finding.code

    summaries = SummarizeDepartureCompositionAreas.new(
      agency: @agency, actor: @staff, departure: @departure, outcome: "supplier",
      readiness: EvaluateDepartureBuilderReadiness.new(agency: @agency, departure: @departure).call
    ).call
    assert_equal %w[services suppliers package review], summaries.map(&:key)
  end

  test "empty overview chooser returns without persisting a choice" do
    sign_in_as @staff
    empty = create_capacity_departure(@agency, name: "Empty Composition Trip")
    get departure_composition_path(empty)
    assert_response :success
    assert_match "What are you starting with?", response.body
    assert_equal 0, empty.service_offers.count
    assert_equal 0, empty.packages.count

    get departure_composition_path(empty)
    assert_match "What are you starting with?", response.body
  end

  test "five composition areas render shell navigation" do
    sign_in_as @staff
    %i[
      departure_composition_path
      services_departure_composition_path
      suppliers_departure_composition_path
      package_departure_composition_path
      review_departure_composition_path
    ].each do |helper|
      get public_send(helper, @departure, outcome: "proposal")
      assert_response :success
      assert_select "nav[aria-label='Composition areas'] a", minimum: 5
      assert_match "outcome=proposal", response.body
    end
  end
end
