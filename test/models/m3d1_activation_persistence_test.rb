require "test_helper"

class M3d1ActivationPersistenceTest < ActiveSupport::TestCase
  test "active Arrangement requires a governing exact version in PostgreSQL" do
    constraint = ActiveRecord::Base.connection.check_constraints(:supplier_arrangements)
      .find { |entry| entry.name == "supplier_arrangements_active_governing_version" }
    assert constraint
    assert_match "governing_version_id IS NOT NULL", constraint.expression
  end

  test "every successor definition family exposes explicit copy lineage" do
    %w[
      arrangement_item_definitions service_occurrence_definitions
      supplier_resource_definitions capacity_pair_definitions
      capacity_pool_definitions supplier_cost_sources supplier_cost_definitions
      supplier_cost_components supplier_cost_component_bases
      supplier_cost_participant_categories supplier_cost_usage_assumptions
      supplier_cost_occupancy_profiles supplier_cost_occupancy_profile_positions
      supplier_commitment_trigger_definitions supplier_deadline_definitions
    ].each do |table|
      assert_includes ActiveRecord::Base.connection.columns(table).map(&:name),
        "copied_from_id", "#{table} must retain predecessor lineage"
    end
  end

  test "trigger model rejects fields outside selected authority shape" do
    trigger = SupplierCommitmentTriggerDefinition.new(
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Guarantee",
      fixed_quantity: 5,
      quantity_basis: "resource_units",
      currency: "USD",
      position: 1
    )
    trigger.validate
    assert_includes trigger.errors[:base], "Authority fields do not match the selected shape"
  end
end
