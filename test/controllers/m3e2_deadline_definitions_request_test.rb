# frozen_string_literal: true

require "test_helper"

class M3e2DeadlineDefinitionsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Deadline Request Supplier")
    @departure = create_capacity_departure(@agency, name: "Deadline Request Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "DeadlineReq", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
  end

  test "create validation failure redisplays fixed-date form fields without crashing" do
    sign_in_as @staff

    assert_no_difference -> { @version.supplier_deadline_definitions.count } do
      post departure_arrangement_version_deadlines_path(
        @departure, @arrangement, @version
      ), params: {
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid,
        supplier_deadline_definition: {
          deadline_type: "option_or_release_date",
          kind: "actionable",
          rule_shape: "fixed_date",
          fixed_date: "2027-03-11",
          precision: "date_only",
          time_zone: "America/New_York",
          commitment_lines: [ {
            authority_shape: "",
            description: "Review retained cabins and release any unretained block by the option date",
            committed_supplier_id: @supplier.id
          } ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/Choose a valid deadline commitment authority/, response.body)
    assert_select "#form-error-summary"
    assert_select "input[name='supplier_deadline_definition[fixed_date]'][value=?]", "2027-03-11"
    assert_select "textarea[name='supplier_deadline_definition[commitment_lines][][description]']",
      text: "Review retained cabins and release any unretained block by the option date"
  end

  test "edit form preserves coverage and commitment lines when only warning lead changes" do
    sign_in_as @staff
    definition = CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @staff, version: @version,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-05-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        warning_lead_days: 2,
        coverage_links: [ { arrangement_item_id: @graph[:item].id } ],
        commitment_lines: [ {
          authority_shape: "fixed_quantity",
          description: "Hold four cabins",
          committed_supplier_id: @supplier.id,
          fixed_quantity: 4,
          quantity_basis: "resource_units"
        } ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    get edit_departure_arrangement_version_deadline_path(
      @departure, @arrangement, @version, definition
    )
    assert_response :success
    assert_select "select[name='supplier_deadline_definition[coverage_links][][arrangement_item_id]']" do
      assert_select "option[selected][value=?]", @graph[:item].id
    end
    assert_select "textarea[name='supplier_deadline_definition[commitment_lines][][description]']",
      text: "Hold four cabins"
    assert_select "input[name='supplier_deadline_definition[commitment_lines][][fixed_quantity]'][value=?]",
      "4"

    patch departure_arrangement_version_deadline_path(
      @departure, @arrangement, @version, definition
    ), params: {
      supplier_deadline_definition: {
        lock_version: definition.lock_version,
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        fixed_date: "2027-05-01",
        precision: "date_only",
        time_zone: "America/New_York",
        warning_lead_days: 7,
        coverage_links: [ { arrangement_item_id: @graph[:item].id } ],
        commitment_lines: [ {
          authority_shape: "fixed_quantity",
          description: "Hold four cabins",
          committed_supplier_id: @supplier.id,
          fixed_quantity: 4,
          quantity_basis: "resource_units"
        } ]
      }
    }
    assert_redirected_to departure_arrangement_version_deadlines_path(
      @departure, @arrangement, @version
    )

    definition.reload
    assert_equal 7, definition.warning_lead_days
    assert_equal 1, definition.supplier_deadline_definition_coverage_links.count
    assert_equal @graph[:item].id,
      definition.supplier_deadline_definition_coverage_links.sole.arrangement_item_id
    line = definition.supplier_deadline_commitment_definition_lines.sole
    assert_equal "Hold four cabins", line.description
    assert_equal 4, line.fixed_quantity
  end
end
