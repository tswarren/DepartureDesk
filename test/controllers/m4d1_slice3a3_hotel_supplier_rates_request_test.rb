# frozen_string_literal: true

require "test_helper"

class M4d1Slice3a3HotelSupplierRatesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(time_zone: "America/New_York")
  end

  test "opening supplier rates creates nothing" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement

    assert_no_difference -> { SupplierCostSource.where(agency: @agency).count } do
      assert_no_difference -> { SupplierCostUsageAssumption.where(agency: @agency).count } do
        get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
      end
    end

    assert_response :success
    assert_select "ol.dd-journey-strip .dd-journey-step", count: 5
    assert_select "a", text: "Agreement", count: 1
    assert_select "a", text: "Review & activate", count: 0
    assert_select "button", text: "Save Supplier rates"
    assert_no_match(/\$4,156|\$685/, response.body)
  end

  test "staff saves the hilton rate schedule and the page reads the one-night block" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")

    assert_no_difference -> { ServiceOffer.where(agency: @agency).count } do
      assert_no_difference -> { SupplierAgreementReference.where(agency: @agency).count } do
        save_rates(arrangement, item, standard, deluxe)
      end
    end
    assert_redirected_to item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    follow_redirect!
    assert_response :success

    assert_equal 17_300, component_amount(item, "November 4", "Standard", "Room night base")
    assert_equal 17_300, component_amount(item, "November 5", "Standard", "Room night base")
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")
    assert_equal 22_300, component_amount(item, "November 5", "Deluxe", "Room night base")
    assert_equal [ 2_000 ], draft_version(item).supplier_cost_components.where(label: "Third occupant").map(&:amount_minor_units).uniq
    assert_equal [ 2_000 ], draft_version(item).supplier_cost_components.where(label: "Fourth occupant").map(&:amount_minor_units).uniq
    assert draft_version(item).supplier_cost_definitions.all?(&:noncommissionable?)
    assert draft_version(item).supplier_cost_definitions.all?(&:forecast_ready?)
    assert draft_version(item).supplier_cost_definitions.all? { |definition|
      definition.readiness_provenance == "Hotel contracted rate workspace"
    }
    assert_equal 0, draft_version(item).supplier_cost_components.where(economic_role: "expected_commission").count
    assert_equal 4, draft_version(item).supplier_cost_usage_assumptions.count
    assert_equal [ 1 ], draft_version(item).supplier_cost_usage_assumptions.pluck(:expected_billable_nights).uniq
    assert_equal 4, draft_version(item).supplier_cost_occupancy_profiles.count
    guest = draft_version(item).supplier_cost_participant_categories.find_by!(
      arrangement_item: item, label: "Hotel guest"
    )
    draft_version(item).supplier_cost_occupancy_profiles.each do |profile|
      positions = profile.supplier_cost_occupancy_profile_positions.order(:occupancy_position)
      assert_equal [ 1, 2, 3, 4 ], positions.pluck(:occupancy_position)
      assert_equal [ guest.id ], positions.pluck(:participant_category_id).uniq
    end
    assert_equal 1, draft_version(item).supplier_cost_participant_categories.where(arrangement_item: item, label: "Hotel guest").count
    assert_equal 4, draft_version(item).supplier_cost_sources.where(arrangement_item: item).count

    assert_match "Standard: $173.00 / $173.00 / $193.00 / $213.00", response.body
    assert_match "Deluxe: $223.00 / $223.00 / $243.00 / $263.00", response.body
    assert_match "Nov 4 base block: $1,311.00", response.body
    assert_match "Nov 5 base block: $2,845.00", response.body
    assert_match "Current pretax contracted-room total: $4,156.00", response.body
    assert_no_match(/\$8,312|\$685/, response.body)
    assert_select "input#noncommissionable[checked]"

    assert_equal 415_600, block_probe(item, nights: 1)
    assert_equal 831_200, block_probe(item, nights: 2)

    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: arrangement
    ).call
    assert_equal 503_600, forecast.totals.forecast_supplier_cost_minor_units
    draft_version(item).supplier_cost_sources.where(arrangement_item: item).each do |source|
      assert_not_includes forecast.incomplete_source_ids, source.id
    end
  end

  test "one rate change leaves the other category and the room inventory alone" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)

    standard_amounts = draft_version(item).supplier_cost_components.where(label: "Room night base").to_a.select do |component|
      component.supplier_cost_definition.supplier_cost_source.supplier_resource_id == standard.supplier_resource_id
    end
    standard_stamps = standard_amounts.map(&:updated_at)
    pool_stamps = draft_version(item).capacity_pool_definitions.order(:id).map { |pool| [ pool.id, pool.updated_at, pool.evidence_reference_note, pool.proposed_opening_quantity ] }
    stay = draft_version(item).service_occurrence_definitions.find_by!(arrangement_item: item, name: "Stay")
    stay_stamp = stay.updated_at

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: lock_params(item), deluxe_base: "230"
    )
    assert_redirected_to item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)

    assert_equal [ 23_000 ], draft_version(item).supplier_cost_components.where(label: "Room night base").to_a.select { |component|
      component.supplier_cost_definition.supplier_cost_source.supplier_resource_id == deluxe.supplier_resource_id
    }.map(&:amount_minor_units).uniq
    assert_equal standard_stamps, standard_amounts.map(&:reload).map(&:updated_at)
    assert_equal pool_stamps, draft_version(item).capacity_pool_definitions.order(:id).map { |pool| [ pool.id, pool.updated_at, pool.evidence_reference_note, pool.proposed_opening_quantity ] }
    assert_equal stay_stamp, stay.reload.updated_at
  end

  test "a pool change moves only the block preview" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    pool = pool_named(item, "November 4", "Standard")
    evidence = pool.evidence_reference_note

    record_openings(arrangement, item, [ [ "2027-11-04", standard, 6 ] ], evidence: false, locks: { pool.id => pool.lock_version })
    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)

    assert_match "Nov 4 base block: $1,484.00", response.body
    assert_match "Current pretax contracted-room total: $4,329.00", response.body
    assert_no_match "$4,156.00", response.body
    assert_equal 17_300, component_amount(item, "November 4", "Standard", "Room night base")
    assert_equal evidence, pool.reload.evidence_reference_note
    updated_assumption = draft_version(item).supplier_cost_usage_assumptions.find_by!(
      arrangement_item: item,
      service_occurrence_id: pool.service_occurrence_id,
      supplier_resource_id: pool.supplier_resource_id
    )
    assert_equal 6, updated_assumption.supplier_cost_occupancy_profiles.sole.resource_unit_count
    forecast = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: arrangement
    ).call
    assert_equal 524_900, forecast.totals.forecast_supplier_cost_minor_units
    assert_equal 0, SupplierAgreementReference.where(supplier_arrangement_version: draft_version(item)).count
  end

  test "a november 5 difference stays visible and is not flattened" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(
      arrangement, item, standard, deluxe,
      bases: {
        standard.supplier_resource_id => { "2027-11-04" => "173", "2027-11-05" => "180" },
        deluxe.supplier_resource_id => "223"
      }
    )
    follow_redirect!
    assert_select "input[value='180.00']"
    assert_select "input[value='173.00']"
    assert_equal 18_000, component_amount(item, "November 5", "Standard", "Room night base")

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: lock_params(item), bases: { standard.supplier_resource_id => "173", deluxe.supplier_resource_id => "223" }
    )
    assert_response :unprocessable_entity
    assert_match "These nights already have different rates.", response.body
    assert_equal 18_000, component_amount(item, "November 5", "Standard", "Room night base")
    assert_equal 17_300, component_amount(item, "November 4", "Standard", "Room night base")
  end

  test "agreement rates use a ready contracted definition and otherwise a ready estimate" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, arrangement, item)

    assert_response :success
    assert_select "#hotel-agreement-rates", text: /Recorded/
    assert_select "#hotel-agreement-rate-authority", text: "Contracted"
    assert_match "$173", response.body
    assert_no_match(/No Supplier rates are recorded/, response.body)

    version = draft_version(item)
    version.supplier_cost_definitions.where(stage: "contracted").update_all(
      status: "working",
      forecast_ready_by_id: nil,
      forecast_ready_at: nil,
      readiness_provenance: nil,
      readiness_fingerprint: nil
    )
    version.supplier_cost_sources.each do |source|
      contracted = source.supplier_cost_definitions.find(&:contracted?)
      estimate = CreateSupplierCostDefinition.new(
        agency: @agency, actor: @staff, source: source,
        source_lock_version: source.reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        attributes: {
          stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up"
        }
      ).call.record
      contracted.supplier_cost_components.order(:position).each do |component|
        attributes = {
          label: component.label,
          economic_role: component.economic_role,
          calculation_kind: component.calculation_kind,
          amount_minor_units: component.amount_minor_units,
          quantity_basis: component.quantity_basis,
          pass_through: component.pass_through
        }
        if component.occupancy_position_from
          attributes[:occupancy_position_from] = component.occupancy_position_from
          attributes[:occupancy_position_to] = component.occupancy_position_to
        end
        CreateSupplierCostComponent.new(
          agency: @agency, actor: @staff, definition: estimate.reload,
          definition_lock_version: estimate.lock_version,
          idempotency_key: SecureRandom.uuid,
          attributes: attributes
        ).call
      end
      estimate.reload.update!(
        status: "forecast_ready",
        forecast_ready_by: @staff,
        forecast_ready_at: Time.current,
        readiness_fingerprint: "agreement-rate-#{estimate.id}"
      )
    end

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, arrangement, item)

    assert_select "#hotel-agreement-rates", text: /In progress/
    assert_select "#hotel-agreement-rate-authority", text: "Estimated"
    assert_match "$173", response.body

  end

  test "generic activation blockers do not prevent supplier confirmation" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    assert_response :redirect

    version = draft_version(item)
    SupplierAgreementReference::KINDS.each do |kind|
      RecordSupplierAgreementReferenceAbsence.new(
        agency: @agency,
        actor: @staff,
        arrangement_item: item,
        scope: "stay",
        kind: kind,
        idempotency_key: SecureRandom.uuid
      ).call
    end

    other_item = arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: other_item,
      name: "Airport transfer",
      category: "ground_transportation",
      capacity_management: "unmanaged",
      default_service_provider: @contractor,
      position: 2
    )
    occurrence = other_item.service_occurrences.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      status: "planned"
    )
    version.service_occurrence_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: other_item,
      service_occurrence: occurrence,
      name: "Airport transfer",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 6),
      time_zone: "America/New_York",
      service_provider: @contractor
    )
    resource = other_item.supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement
    )
    version.supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: other_item,
      supplier_resource: resource,
      name: "Motorcoach seat",
      position: 1
    )

    readiness = SupplierArrangementActivationReadiness.new(
      agency: @agency,
      arrangement: arrangement,
      version: version
    ).call
    assert_includes readiness.blockers.map(&:code), :item_coverage_missing

    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: Time.current
    )

    review = CompileHotelActivationReview.new(
      agency: @agency,
      departure: @departure,
      arrangement: arrangement,
      version: version,
      item: item
    ).call
    assert review.confirmation_allowed
    assert_not review.activation_allowed

    post item_hotel_review_confirmation_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: {
        version_id: version.id,
        idempotency_key: SecureRandom.uuid,
        confirmation: {
          evidence_kind: "supplier_confirmation",
          evidence_on: "2026-10-02",
          channel: "email",
          reference_note: "Hotel confirmed the reviewed agreement.",
          confirmed_without_identifier_reason: "No Supplier number was issued."
        }
      }

    assert_response :redirect
    assert SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
    confirmed_review = CompileHotelActivationReview.new(
      agency: @agency,
      departure: @departure,
      arrangement: arrangement,
      version: version.reload,
      item: item
    ).call
    assert_not confirmed_review.activation_allowed
  end

  test "the canonical Hilton agreement confirms and activates through the typed Hotel path" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    assert_response :redirect

    version = draft_version(item)
    [
      [ 41_560, "2026-10-01" ],
      [ 187_020, "2027-05-07" ],
      [ 187_020, "2027-10-04" ]
    ].each_with_index do |(amount, date), index|
      CreateSupplierDepositRequirementDefinition.new(
        agency: @agency,
        actor: @staff,
        version: version.reload,
        version_lock_version: version.lock_version,
        idempotency_key: "hilton-review-deposit-#{index}-#{SecureRandom.uuid}",
        attributes: {
          amount_shape: "fixed_amount",
          fixed_amount_minor_units: amount,
          currency: "USD",
          rule_shape: "fixed_date",
          rule_parameters: { "date" => date },
          precision: "date_only",
          time_zone: "America/New_York",
          description: "Hilton deposit #{index + 1}",
          coverage_links: [ { arrangement_item_id: item.id } ],
          cost_links: [],
          contributor_definition_ids: []
        }
      ).call
    end

    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: version.reload,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        deadline_type: "rooming_list_due",
        kind: "actionable",
        rule_shape: "fixed_local_datetime",
        rule_parameters: { "datetime" => "2027-10-03T17:00:00" },
        precision: "local_date_time",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: item.id } ],
        commitment_lines: []
      }
    ).call

    {
      "deposit_derivation" => {
        governing_wording: "The three fixed deposits derive from the contracted room block.",
        original_wording: nil
      },
      "attrition" => {
        governing_wording: "The Hotel agreement contains the governing attrition provision.",
        original_wording: nil
      },
      "deposit_refund" => {
        governing_wording: "The Hotel refunds any remaining deposit balance after the stay.",
        original_wording: "Deposits are non-refundable."
      },
      "destination_fee" => {
        governing_wording: "The destination fee is waived.",
        original_wording: nil
      },
      "additional_nights" => {
        governing_wording: "Additional nights are available on request.",
        original_wording: nil
      },
      "early_departure" => {
        governing_wording: "Early departure follows the Hotel agreement.",
        original_wording: nil
      }
    }.each do |kind, wording|
      RecordSupplierAgreementReference.new(
        agency: @agency,
        actor: @staff,
        arrangement_item: item,
        scope: "stay",
        kind: kind,
        governing_wording: wording[:governing_wording],
        original_wording: wording[:original_wording],
        source_description: "Hilton Fort Lauderdale Marina agreement",
        idempotency_key: SecureRandom.uuid
      ).call
    end
    RecordSupplierAgreementReferenceAbsence.new(
      agency: @agency,
      actor: @staff,
      arrangement_item: item,
      scope: "stay",
      kind: "cancellation",
      idempotency_key: SecureRandom.uuid
    ).call

    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: Time.current
    )

    review = CompileHotelActivationReview.new(
      agency: @agency,
      departure: @departure,
      arrangement: arrangement,
      version: version.reload,
      item: item
    ).call
    assert review.confirmation_allowed
    assert_equal 3, review.workspace.deposits.count
    assert_equal [ 41_560, 187_020, 187_020 ],
      review.workspace.deposits.map { |row| row.definition.fixed_amount_minor_units }
    assert_equal 1, review.workspace.deadlines.count { |row| row.definition.deadline_type == "rooming_list_due" }

    post item_hotel_review_confirmation_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: {
        version_id: version.id,
        idempotency_key: SecureRandom.uuid,
        confirmation: {
          evidence_kind: "supplier_confirmation",
          evidence_on: "2026-10-02",
          channel: "email",
          reference_note: "Hilton confirmed the reviewed agreement.",
          confirmed_without_identifier_reason: "No Supplier number was issued."
        }
      }
    assert_response :redirect

    version.reload
    arrangement.reload
    confirmation = version.supplier_confirmations.sole
    get item_hotel_review_departure_arrangement_hotel_path(
      @departure, arrangement, item, version_id: version.id
    )
    assert_response :success
    assert_select "#hotel-review-elapsed-dates", text: /Supplier deposit.*2026-10-01/m
    assert_select "#hotel-review-cost-ack", count: 0
    assert_select "#hotel-review-trigger-ack", count: 0
    assert_select "button", text: "Activate arrangement"

    post item_hotel_review_activation_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: {
        version_id: version.id,
        idempotency_key: SecureRandom.uuid,
        arrangement_lock_version: arrangement.lock_version,
        version_lock_version: version.lock_version,
        existing_confirmation_id: confirmation.id,
        elapsed_deadlines_acknowledged: "1"
      }
    assert_response :redirect
    assert_equal "active", arrangement.reload.status
    assert_equal version.id, arrangement.governing_version_id
    assert_predicate version.reload, :activated?
  end

  test "a no-deposit no-rooming-list hotel can confirm and activate through the typed path" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    assert_response :redirect

    version = draft_version(item)
    SupplierAgreementReference::KINDS.each do |kind|
      RecordSupplierAgreementReferenceAbsence.new(
        agency: @agency,
        actor: @staff,
        arrangement_item: item,
        scope: "stay",
        kind: kind,
        idempotency_key: SecureRandom.uuid
      ).call
    end
    assert_equal 0, version.supplier_deposit_requirement_definitions.count
    assert_equal 0, version.supplier_deadline_definitions.count

    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900000) + 100000}",
      first_activated_at: Time.current
    )

    get item_hotel_review_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_select "#hotel-review-deposits", text: /No Supplier deposits recorded/
    assert_select "#hotel-review-deadlines", text: /No rooming list recorded/
    assert_no_match(/cost-source|commitment-trigger|forecast.ready/i, response.body)
    assert_select "button", text: "Confirm Supplier agreement"

    post item_hotel_review_confirmation_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: {
        version_id: version.id,
        idempotency_key: SecureRandom.uuid,
        confirmation: {
          evidence_kind: "supplier_confirmation",
          evidence_on: "2026-10-02",
          channel: "email",
          reference_note: "Hotel confirmed the reviewed agreement.",
          confirmed_without_identifier_reason: "No Supplier number was issued."
        }
      }
    assert_redirected_to item_hotel_review_departure_arrangement_hotel_path(
      @departure, arrangement, item, version_id: version.id
    )

    confirmation = version.supplier_confirmations.sole
    version.reload
    arrangement.reload
    get item_hotel_review_departure_arrangement_hotel_path(
      @departure, arrangement, item, version_id: version.id
    )
    assert_select "button", text: "Activate arrangement"
    assert_select "#hotel-review-cost-ack", count: 0
    assert_select "#hotel-review-trigger-ack", count: 0

    post item_hotel_review_activation_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: {
        version_id: version.id,
        idempotency_key: SecureRandom.uuid,
        arrangement_lock_version: arrangement.lock_version,
        version_lock_version: version.lock_version,
        existing_confirmation_id: confirmation.id
      }
    assert_response :redirect
    assert_equal "active", arrangement.reload.status
    assert_equal version.id, arrangement.governing_version_id
    assert_predicate version.reload, :activated?
  end

  test "a renamed Hotel occupancy profile is Advanced and is not silently repaired" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)

    assumption = draft_version(item).supplier_cost_usage_assumptions.order(:id).first
    profile = assumption.supplier_cost_occupancy_profiles.sole
    UpdateSupplierCostOccupancyProfile.new(
      agency: @agency,
      actor: @staff,
      profile: profile,
      lock_version: profile.lock_version,
      attributes: {
        label: "Custom occupancy mix",
        resource_unit_count: profile.resource_unit_count
      }
    ).call

    get item_hotel_agreement_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_select "#hotel-agreement-rates", text: /Needs attention/
    assert_match(/Advanced Supplier cost shape/, response.body)

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: rate_params(standard, deluxe, locks: lock_params(item))
    assert_response :unprocessable_entity
    assert_match "Advanced Supplier cost shape", response.body
    assert_equal "Custom occupancy mix", profile.reload.label
  end

  test "a stale definition lock rejects the whole rate save" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    locks = lock_params(item)
    definition = source_for(item, "November 4", "Standard").supplier_cost_definitions.sole
    definition.touch

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: locks, deluxe_base: "230"
    )
    assert_response :unprocessable_entity
    assert_match "Supplier rates changed while you were editing them.", response.body
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")
    assert_equal 17_300, component_amount(item, "November 4", "Standard", "Room night base")
  end

  test "an invalid amount rolls back and redisplays the submission" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")

    assert_no_difference -> { SupplierCostSource.where(agency: @agency).count } do
      patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
        standard, deluxe, bases: { standard.supplier_resource_id => "abc", deluxe.supplier_resource_id => "223" }
      )
    end
    assert_response :unprocessable_entity
    assert_select "input[value='abc']"

    save_rates(arrangement, item, standard, deluxe)
    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: lock_params(item), deluxe_base: "nope"
    )
    assert_response :unprocessable_entity
    assert_select "input[value='nope']"
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")
  end

  test "a blank supplement removes the component and leaves the other rates in place" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)
    base = source_for(item, "November 4", "Standard").supplier_cost_definitions.sole.supplier_cost_components.find_by!(label: "Room night base")
    fourth = source_for(item, "November 4", "Standard").supplier_cost_definitions.sole.supplier_cost_components.find_by!(label: "Fourth occupant")
    base_stamp = base.updated_at

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: lock_params(item), third: ""
    )
    assert_redirected_to item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    follow_redirect!

    assert_empty draft_version(item).supplier_cost_components.where(label: "Third occupant")
    assert_equal 0, draft_version(item).supplier_cost_components.where(amount_minor_units: 0, occupancy_position_from: 3).count
    assert_equal 2_000, fourth.reload.amount_minor_units
    assert_equal 4, fourth.occupancy_position_from
    assert_equal 4, fourth.occupancy_position_to
    assert_equal base_stamp, base.reload.updated_at
    assert_equal 17_300, base.amount_minor_units
    assert_match "Standard: $173.00 / $173.00 / $173.00 / $193.00", response.body
    assert_match "Deluxe: $223.00 / $223.00 / $223.00 / $243.00", response.body

    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe,
      locks: lock_params(item),
      third: "",
      bases: { standard.supplier_resource_id => "", deluxe.supplier_resource_id => "223" }
    )
    assert_response :unprocessable_entity
    assert_match "Enter a Supplier rate.", response.body
    assert_equal 17_300, component_amount(item, "November 4", "Standard", "Room night base")
    assert_empty draft_version(item).supplier_cost_components.where(label: "Third occupant")
  end

  test "saving supplier rates requires the noncommissionable acknowledgement" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")

    assert_no_difference -> { SupplierCostSource.where(agency: @agency).count } do
      patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
        standard, deluxe, commission: false
      )
    end
    assert_response :unprocessable_entity
    assert_match "Confirm Net and noncommissionable before saving Supplier rates.", response.body
    assert_select "input#noncommissionable[checked]", count: 0

    save_rates(arrangement, item, standard, deluxe)
    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
      standard, deluxe, locks: lock_params(item), deluxe_base: "230", commission: false
    )
    assert_response :unprocessable_entity
    assert_match "Confirm Net and noncommissionable before saving Supplier rates.", response.body
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")
    assert draft_version(item).supplier_cost_definitions.all?(&:noncommissionable?)
  end

  test "occupancy illustrations stop at the category maximum occupancy" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    UpdateSupplierResource.new(
      agency: @agency,
      actor: @staff,
      definition: standard,
      lock_version: standard.lock_version,
      attributes: { name: "Standard", maximum_occupancy: 3 }
    ).call

    save_rates(arrangement, item, standard, deluxe)
    follow_redirect!
    assert_match "Standard: $173.00 / $173.00 / $193.00", response.body
    assert_no_match "Standard: $173.00 / $173.00 / $193.00 / ", response.body
    assert_match "Deluxe: $223.00 / $223.00 / $243.00 / $263.00", response.body
    standard_assumptions = draft_version(item).supplier_cost_usage_assumptions.where(
      supplier_resource_id: standard.supplier_resource_id
    )
    standard_assumptions.each do |assumption|
      assert_equal [ 1, 2, 3 ],
        assumption.supplier_cost_occupancy_profiles.sole
          .supplier_cost_occupancy_profile_positions.order(:occupancy_position).pluck(:occupancy_position)
    end
  end

  test "an unsupported cost graph stays unchanged and links to advanced supplier cost planning" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    night = draft_version(item).service_occurrence_definitions.find_by!(arrangement_item: item, name: "November 4")
    source = add_percentage_source!(item, night.service_occurrence, standard.supplier_resource)
    component = source.supplier_cost_definitions.sole.supplier_cost_components.sole
    stamp = component.updated_at

    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_select "a", text: "Advanced Supplier cost planning"

    assert_no_difference -> { SupplierCostSource.where(supplier_arrangement_version: draft_version(item)).count } do
      patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
        standard, deluxe,
        locks: lock_params(item),
        bases: {
          standard.supplier_resource_id => { "2027-11-04" => "173", "2027-11-05" => "173" },
          deluxe.supplier_resource_id => "223"
        }
      )
    end
    assert_response :unprocessable_entity
    assert_equal stamp, component.reload.updated_at
    assert_equal "percentage", component.calculation_kind

    save_rates(
      arrangement, item, standard, deluxe,
      locks: lock_params(item),
      bases: {
        standard.supplier_resource_id => { "2027-11-05" => "173" },
        deluxe.supplier_resource_id => "223"
      }
    )
    assert_redirected_to item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_equal stamp, component.reload.updated_at
    assert_equal "percentage", component.reload.calculation_kind
    assert_equal 22_300, component_amount(item, "November 5", "Deluxe", "Room night base")
    assert_nil source_for(item, "November 4", "Standard").supplier_cost_definitions.sole.supplier_cost_components.find_by(label: "Room night base")
  end

  test "a second hotel item stays isolated" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)

    post departure_arrangement_hotel_stays_path(@departure, arrangement), params: stay_params("Second hotel")
    second = item_named("Second hotel")
    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, second)
    assert_response :success
    assert_no_match "$4,156.00", response.body
    assert_equal 0, draft_version(second).supplier_cost_sources.where(arrangement_item: second).count
    assert_equal 4, draft_version(item).supplier_cost_sources.where(arrangement_item: item).count
  end

  test "a viewer cannot save, another agency is not found, and an activated version is read only" do
    sign_in_as @staff
    item = hilton_inventory
    arrangement = item.supplier_arrangement
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    save_rates(arrangement, item, standard, deluxe)

    sign_in_as agency_users(:harbor_viewer)
    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_select "button", text: "Save Supplier rates", count: 0
    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(standard, deluxe, deluxe_base: "230")
    assert_redirected_to root_path
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")

    sign_in_as agency_users(:cove_admin)
    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :not_found

    sign_in_as @staff
    activate_arrangement!(arrangement)
    get item_rates_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_select "button", text: "Save Supplier rates", count: 0
    assert_no_difference -> { SupplierCostComponent.where(agency: @agency).count } do
      patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item), params: rate_params(
        standard, deluxe, locks: lock_params(item), deluxe_base: "230"
      )
    end
    assert_response :unprocessable_entity
    assert_equal 22_300, component_amount(item, "November 4", "Deluxe", "Room night base")
  end

  private

  def stay_params(name, ends_on: "2027-11-06")
    {
      idempotency_key: SecureRandom.uuid,
      arrangement: { contracting_supplier_id: @contractor.id },
      item: { name: name },
      occurrence: {
        starts_on: "2027-11-04",
        ends_on: ends_on,
        starts_at_local: "15:00",
        ends_at_local: "12:00",
        time_zone: "America/New_York"
      }
    }
  end

  def resource_params(name)
    {
      idempotency_key: SecureRandom.uuid,
      resource: { name: name, maximum_occupancy: 4 }
    }
  end

  def record_openings(arrangement, item, entries, evidence: true, locks: {})
    patch item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: matrix_params(entries, evidence: evidence, locks: locks)
  end

  def matrix_params(entries, evidence: true, locks: {})
    quantities = {}
    entries.each do |date, resource, quantity|
      quantities[resource.supplier_resource_id] ||= {}
      quantities[resource.supplier_resource_id][date.to_s] = quantity
    end
    payload = { idempotency_key: SecureRandom.uuid, quantity: quantities }
    payload[:pool_lock] = locks if locks.present?
    if evidence
      payload[:evidence] = {
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Hilton group contract"
      }
    end
    payload
  end

  def hilton_inventory
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Deluxe")
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    record_openings(arrangement, item, [
      [ "2027-11-04", standard, 5 ],
      [ "2027-11-04", deluxe, 2 ],
      [ "2027-11-05", standard, 10 ],
      [ "2027-11-05", deluxe, 5 ]
    ])
    assert_response :redirect
    item
  end

  def save_rates(arrangement, item, standard, deluxe, bases: nil, locks: {}, deluxe_base: "223")
    patch item_rates_departure_arrangement_hotel_path(@departure, arrangement, item),
      params: rate_params(standard, deluxe, bases: bases, locks: locks, deluxe_base: deluxe_base)
  end

  def rate_params(standard, deluxe, bases: nil, locks: {}, deluxe_base: "223", third: "20", fourth: "20", commission: true)
    payload = {
      idempotency_key: SecureRandom.uuid,
      base: bases || {
        standard.supplier_resource_id => "173",
        deluxe.supplier_resource_id => deluxe_base
      },
      supplement: { "3" => third, "4" => fourth },
      definition_lock: locks[:definition_lock] || {},
      component_lock: locks[:component_lock] || {}
    }
    payload[:noncommissionable] = "1" if commission
    payload
  end

  def lock_params(item)
    version = draft_version(item)
    {
      definition_lock: version.supplier_cost_definitions.to_h { |definition| [ definition.id, definition.lock_version ] },
      component_lock: version.supplier_cost_components.to_h { |component| [ component.id, component.lock_version ] }
    }
  end

  def create_stay(name)
    post departure_composition_suppliers_hotels_path(@departure), params: stay_params(name)
    item_named(name)
  end

  def item_named(name)
    definition = ArrangementItemDefinition.joins(:supplier_arrangement_version).find_by!(agency: @agency, name: name)
    definition.arrangement_item
  end

  def draft_version(item)
    item.supplier_arrangement.editable_version
  end

  def resource_named(item, name)
    draft_version(item).supplier_resource_definitions.find_by!(arrangement_item: item, name: name)
  end

  def pool_named(item, night_name, resource_name)
    night = draft_version(item).service_occurrence_definitions.find_by!(arrangement_item: item, name: night_name)
    resource = resource_named(item, resource_name)
    draft_version(item).capacity_pool_definitions.find_by!(
      service_occurrence_id: night.service_occurrence_id,
      supplier_resource_id: resource.supplier_resource_id
    )
  end

  def source_for(item, night_name, resource_name)
    version = draft_version(item)
    night = version.service_occurrence_definitions.find_by!(arrangement_item: item, name: night_name)
    resource = resource_named(item, resource_name)
    version.supplier_cost_sources.find_by!(
      arrangement_item: item,
      service_occurrence_id: night.service_occurrence_id,
      supplier_resource_id: resource.supplier_resource_id
    )
  end

  def component_amount(item, night_name, resource_name, label)
    source_for(item, night_name, resource_name).supplier_cost_definitions.sole.supplier_cost_components.find_by!(label: label).amount_minor_units
  end

  def block_probe(item, nights:)
    version = draft_version(item)
    version.supplier_cost_sources.where(arrangement_item: item).sum do |source|
      definition = source.supplier_cost_definitions.find_by!(stage: "contracted")
      pool = version.capacity_pool_definitions.find_by!(
        service_occurrence_id: source.service_occurrence_id,
        supplier_resource_id: source.supplier_resource_id
      )
      units = pool.proposed_opening_quantity
      profile = EvaluateSupplierCostForecast::PreviewProfile.new(id: "probe-#{source.id}-#{nights}", resource_unit_count: units)
      usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
        id: "probe-usage-#{source.id}-#{nights}",
        expected_persons: nil,
        expected_resource_units: units,
        expected_billable_nights: nights
      )
      rows = EvaluateSupplierCostForecast.new(
        agency: @agency,
        departure: @departure,
        arrangement: item.supplier_arrangement,
        version: version,
        probe_definition: definition
      ).call_attributed_sources(
        sources: [ source ],
        usage: usage,
        profiles: [ profile ],
        positions_by_profile: { profile.id => [] }
      )
      rows.sole.totals.forecast_supplier_cost_minor_units
    end
  end

  def add_percentage_source!(item, occurrence, resource)
    version = draft_version(item)
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @staff, arrangement: item.supplier_arrangement,
      version_lock_version: version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: item.id,
        service_occurrence_id: occurrence.id,
        supplier_resource_id: resource.id,
        charging_supplier_id: @contractor.id,
        label: "Unsupported night"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @staff, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @staff, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Unexpected percentage",
        economic_role: "supplier_charge",
        calculation_kind: "percentage",
        percentage: "10",
        percentage_treatment: "additive",
        pass_through: false
      }
    ).call
    source
  end

  def activate_arrangement!(arrangement)
    @departure.update!(status: "active", departure_reference: "D-930310", first_activated_at: Time.current)
    version = arrangement.versions.find_by!(status: "draft")
    version.update!(status: "activated", activated_at: Time.current)
    arrangement.update!(status: "active", governing_version: version)
    version
  end
end
