# frozen_string_literal: true

require "test_helper"

# M4D.1 Slice 2A.2R3 — rate-shape detector remediation regressions.
class CruiseSupplierRateShapeDetectorRemediationTest < ActiveSupport::TestCase
  include M3CCostScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(**sailing_arguments).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    cabin = create_cabin(@arrangement, @version)
    @resource = cabin.record.resource
    @version.reload
  end

  test "shared percentage spanning profiles reopens as one shared component" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          shared: true,
          add_cells: %w[base_fare:first_second base_fare:additional base_fare:single_supplement],
          subtract_cells: %w[discount:first_second]
        }
      )
    ).call

    shape = detect_shape
    assert shape.compatible?
    commission = shape.projected_matrix.fetch(:commission)
    assert_equal "percentage", commission.fetch(:method)
    assert commission.fetch(:shared)
    assert_includes commission.fetch(:add_cells), "base_fare:first_second"
    assert_includes commission.fetch(:add_cells), "base_fare:additional"
    assert_equal 1, shape.definition.supplier_cost_components.where(economic_role: "expected_commission").count
  end

  test "profile specific percentages reopen with correct rate and bases per profile" do
    adult_first = CruiseSupplierRateSupport.encode_profile_key(:first_second, category: "Adult")
    child_additional = CruiseSupplierRateSupport.encode_profile_key(:additional, category: "Child")
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      profiles: [
        { family: "first_second", category: "Adult" },
        { family: "additional", category: "Child" },
        { family: "every_traveler" }
      ],
      custom_rows: [],
      cells: {
        CruiseSupplierRateSupport.cell_key(:base_fare, adult_first) => "1000.00",
        CruiseSupplierRateSupport.cell_key(:discount, adult_first) => "100.00",
        CruiseSupplierRateSupport.cell_key(:base_fare, child_additional) => "400.00",
        CruiseSupplierRateSupport.cell_key(:nccf, :every_traveler) => "150.00"
      },
      commission: {
        method: "percentage",
        shared: false,
        add_cells: [
          CruiseSupplierRateSupport.cell_key(:base_fare, adult_first),
          CruiseSupplierRateSupport.cell_key(:base_fare, child_additional)
        ],
        subtract_cells: [
          CruiseSupplierRateSupport.cell_key(:discount, adult_first)
        ],
        rates: {
          adult_first => "10",
          child_additional => "5"
        }
      },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    shape = detect_shape
    assert shape.compatible?
    commission = shape.projected_matrix.fetch(:commission)
    refute commission.fetch(:shared)
    assert_in_delta 0.10, commission.fetch(:rates).fetch(adult_first), 0.0001
    assert_in_delta 0.05, commission.fetch(:rates).fetch(child_additional), 0.0001
    assert_includes commission.fetch(:add_cells), CruiseSupplierRateSupport.cell_key(:base_fare, adult_first)
    assert_includes commission.fetch(:add_cells), CruiseSupplierRateSupport.cell_key(:base_fare, child_additional)
    assert_includes commission.fetch(:subtract_cells), CruiseSupplierRateSupport.cell_key(:discount, adult_first)
  end

  test "custom rows that slugify identically retain distinct commission bases" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        custom_rows: [
          { key: "port_fee", label: "Port Fee", economic_role: "supplier_charge" },
          { key: "port_fee_2", label: "Port-Fee", economic_role: "supplier_charge" }
        ],
        cells: smith_cells.merge(
          "port_fee:first_second" => "25.00",
          "port_fee_2:first_second" => "15.00"
        ),
        commission: {
          method: "percentage",
          percentage: "10",
          shared: true,
          add_cells: %w[base_fare:first_second port_fee:first_second port_fee_2:first_second],
          subtract_cells: []
        }
      )
    ).call

    shape = detect_shape
    assert shape.compatible?, shape.reasons.inspect
    custom_keys = shape.projected_matrix.fetch(:custom_rows).map { |row| row.fetch(:key) }
    assert_includes custom_keys, "port_fee"
    assert_includes custom_keys, "port_fee_2"
    assert_equal "port_fee", CruiseSupplierRateSupport.slugify_custom_row_key("Port Fee")
    assert_equal "port_fee", CruiseSupplierRateSupport.slugify_custom_row_key("Port-Fee")

    commission = shape.projected_matrix.fetch(:commission)
    add_cells = commission.fetch(:add_cells)
    assert_includes add_cells, "port_fee:first_second"
    assert_includes add_cells, "port_fee_2:first_second"
    refute_equal add_cells.count("port_fee:first_second"), 2
  end

  test "cross profile percentage component fails closed" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          shared: false,
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: [],
          rates: {
            "first_second" => "10",
            "additional" => "5"
          }
        }
      )
    ).call

    definition = current_definition
    categories_by_id = participant_categories_by_id(definition)
    commissions = definition.supplier_cost_components.where(economic_role: "expected_commission").order(:position, :id).to_a
    assert_equal 2, commissions.size
    first_second_fare, additional_fare = base_fare_for_profiles(definition, categories_by_id, %w[first_second additional])
    # Force one profile-specific component to span both profiles.
    commissions.first.supplier_cost_component_bases.destroy_all
    link_base!(commissions.first, first_second_fare, "add", 1)
    link_base!(commissions.first, additional_fare, "add", 2)

    shape = detect_shape
    refute shape.compatible?
    assert shape.reasons.any? { |reason| reason.include?("exactly one profile") }
  end

  test "overlapping percentage components for one profile fail closed" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          shared: false,
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: [],
          rates: {
            "first_second" => "10",
            "additional" => "5"
          }
        }
      )
    ).call

    definition = current_definition
    categories_by_id = participant_categories_by_id(definition)
    commissions = definition.supplier_cost_components.where(economic_role: "expected_commission").order(:position, :id).to_a
    first_second_fare, = base_fare_for_profiles(definition, categories_by_id, %w[first_second])
    # Retarget the second commission onto the same profile as the first.
    commissions.second.supplier_cost_component_bases.destroy_all
    link_base!(commissions.second, first_second_fare, "add", 1)

    shape = detect_shape
    refute shape.compatible?
    assert shape.reasons.any? { |reason| reason.include?("one percentage commission component per rate profile") }
  end

  test "missing or orphaned commission base fails closed" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second],
          subtract_cells: []
        }
      )
    ).call

    definition = current_definition
    commission = definition.supplier_cost_components.find_by!(economic_role: "expected_commission")
    earlier = definition.supplier_cost_components
      .where.not(economic_role: "expected_commission")
      .order(:position, :id)
      .first
    assert earlier
    # Keep the link, but make the base non-projectable as a matrix cell.
    earlier.update_columns(
      quantity_basis: "nights",
      occupancy_position_from: nil,
      occupancy_position_to: nil,
      participant_category_id: nil
    )
    commission.supplier_cost_component_bases.destroy_all
    link_base!(commission, earlier, "add", 1)

    shape = detect_shape
    refute shape.compatible?
    assert shape.reasons.any? { |reason|
      reason.include?("projected matrix cells") ||
        reason.include?("cannot reopen") ||
        reason.include?("matrix rate cells")
    }
  end

  test "reopen unchanged save reopen preserves topology and totals" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          shared: true,
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: %w[discount:first_second]
        }
      )
    ).call

    before = detect_shape
    assert before.compatible?
    before_commission = before.projected_matrix.fetch(:commission).deep_dup
    before_preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    before_totals = before_preview.illustrations.index_by(&:key).transform_values do |row|
      [ row.gross_minor_units, row.commission_minor_units, row.net_minor_units ]
    end

    matrix = before.projected_matrix
    UpdateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      profiles: matrix.fetch(:profile_details).map { |detail|
        {
          family: detail.fetch(:family),
          category: detail[:category],
          occupancy_position_from: detail[:occupancy_position_from],
          occupancy_position_to: detail[:occupancy_position_to]
        }.compact
      },
      custom_rows: matrix.fetch(:custom_rows),
      cells: matrix.fetch(:cells).transform_values { |minor| format("%.2f", minor / 100.0) },
      commission: {
        method: "percentage",
        shared: true,
        percentage: (before_commission.fetch(:rate) * 100).to_s,
        add_cells: before_commission.fetch(:add_cells),
        subtract_cells: before_commission.fetch(:subtract_cells)
      },
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: before.definition.lock_version
    ).call

    after = detect_shape
    assert after.compatible?
    assert_equal before_commission.fetch(:shared), after.projected_matrix.fetch(:commission).fetch(:shared)
    assert_equal before_commission.fetch(:add_cells).sort, after.projected_matrix.fetch(:commission).fetch(:add_cells).sort
    assert_equal before_commission.fetch(:subtract_cells).sort, after.projected_matrix.fetch(:commission).fetch(:subtract_cells).sort
    assert_in_delta before_commission.fetch(:rate), after.projected_matrix.fetch(:commission).fetch(:rate), 0.0001

    after_preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    after_totals = after_preview.illustrations.index_by(&:key).transform_values do |row|
      [ row.gross_minor_units, row.commission_minor_units, row.net_minor_units ]
    end
    assert_equal before_totals, after_totals
  end

  private

  def detect_shape
    DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
  end

  def participant_categories_by_id(definition)
    @version.supplier_cost_participant_categories
      .where(arrangement_item_id: definition.supplier_cost_source.arrangement_item_id)
      .index_by(&:id)
  end

  def base_fare_for_profiles(definition, categories_by_id, profile_keys)
    fares = definition.supplier_cost_components.where(label: "Base Fare").to_a
    profile_keys.map do |profile_key|
      fare = fares.find { |component|
        CruiseSupplierRateSupport.profile_key_for_component(
          component, categories_by_id: categories_by_id
        ).to_s == profile_key
      }
      assert fare, "missing Base Fare for #{profile_key}"
      fare
    end
  end

  def link_base!(commission, base, direction, position)
    SupplierCostComponentBase.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: commission.supplier_cost_definition,
      supplier_cost_component: commission,
      base_component: base,
      direction: direction,
      position: position
    )
  end

  def sailing_arguments
    {
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    }
  end

  def create_cabin(arrangement, version)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def smith_terms
    {
      first_second_fare: "1624.00",
      additional_fare: "406.00",
      single_supplement: "1624.00",
      nccf: "320.00",
      first_second_discount: "150.00",
      additional_discount: "37.50",
      taxes_fees: "137.00"
    }
  end

  def smith_cells
    {
      "base_fare:first_second" => "1624.00",
      "base_fare:additional" => "406.00",
      "base_fare:single_supplement" => "1624.00",
      "nccf:every_traveler" => "320.00",
      "discount:first_second" => "150.00",
      "discount:additional" => "37.50",
      "taxes_fees:every_traveler" => "137.00"
    }
  end

  def create_smith_rates!
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      terms: smith_terms,
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def current_definition
    detect_shape.definition
  end

  def update_args
    definition = current_definition
    {
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      terms: smith_terms,
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: definition.lock_version
    }
  end
end
