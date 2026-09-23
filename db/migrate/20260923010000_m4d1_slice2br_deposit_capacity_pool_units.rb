# frozen_string_literal: true

class M4d1Slice2brDepositCapacityPoolUnits < ActiveRecord::Migration[8.1]
  QUANTITY_BASES = %w[resource_units traveler_positions explicit capacity_pool_units].freeze

  def up
    remove_check_constraint :supplier_deposit_requirement_definitions,
      name: "deposit_definitions_quantity_basis"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "quantity_basis IS NULL OR quantity_basis IN (#{sql_list(QUANTITY_BASES)})",
      name: "deposit_definitions_quantity_basis"

    remove_check_constraint :supplier_deposit_requirement_definitions,
      name: "deposit_definitions_amount_fields"
    add_check_constraint :supplier_deposit_requirement_definitions,
      amount_fields_sql,
      name: "deposit_definitions_amount_fields"

    create_contributor_links!
  end

  def down
    drop_table :supplier_deposit_requirement_definition_contributor_links, if_exists: true

    remove_check_constraint :supplier_deposit_requirement_definitions,
      name: "deposit_definitions_amount_fields"
    add_check_constraint :supplier_deposit_requirement_definitions,
      legacy_amount_fields_sql,
      name: "deposit_definitions_amount_fields"

    remove_check_constraint :supplier_deposit_requirement_definitions,
      name: "deposit_definitions_quantity_basis"
    add_check_constraint :supplier_deposit_requirement_definitions,
      "quantity_basis IS NULL OR quantity_basis IN ('resource_units', 'traveler_positions', 'explicit')",
      name: "deposit_definitions_quantity_basis"
  end

  private

  def create_contributor_links!
    create_table :supplier_deposit_requirement_definition_contributor_links,
      id: :uuid, default: -> { "uuidv7()" } do |table|
      table.uuid :agency_id, null: false
      table.uuid :departure_id, null: false
      table.uuid :supplier_arrangement_id, null: false
      table.uuid :supplier_arrangement_version_id, null: false
      table.uuid :supplier_deposit_requirement_definition_id, null: false
      table.uuid :contributor_definition_id, null: false
      table.integer :position, null: false
      table.timestamps null: false
    end

    add_index :supplier_deposit_requirement_definition_contributor_links,
      [ :id, :agency_id ], unique: true, name: "index_dep_contrib_on_id_agency"
    add_index :supplier_deposit_requirement_definition_contributor_links,
      [ :id, :departure_id, :agency_id ], unique: true,
      name: "index_dep_contrib_on_id_departure_agency"
    add_index :supplier_deposit_requirement_definition_contributor_links,
      [ :supplier_deposit_requirement_definition_id, :position ], unique: true,
      name: "index_deposit_contributor_links_on_definition_position"
    add_index :supplier_deposit_requirement_definition_contributor_links,
      [ :supplier_deposit_requirement_definition_id, :contributor_definition_id ], unique: true,
      name: "index_deposit_contributor_links_on_definition_contributor"
    add_index :supplier_deposit_requirement_definition_contributor_links,
      [ :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      unique: true, name: "index_deposit_contributor_links_on_full_owner"

    add_foreign_key :supplier_deposit_requirement_definition_contributor_links,
      :supplier_arrangement_versions,
      column: [ :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id ],
      primary_key: [ :id, :supplier_arrangement_id, :departure_id, :agency_id ],
      name: "deposit_contributor_links_version_fk"
    add_foreign_key :supplier_deposit_requirement_definition_contributor_links,
      :supplier_deposit_requirement_definitions,
      column: [
        :supplier_deposit_requirement_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_contributor_links_definition_fk"
    add_foreign_key :supplier_deposit_requirement_definition_contributor_links,
      :supplier_deposit_requirement_definitions,
      column: [
        :contributor_definition_id, :supplier_arrangement_version_id,
        :supplier_arrangement_id, :departure_id, :agency_id
      ],
      primary_key: [
        :id, :supplier_arrangement_version_id, :supplier_arrangement_id, :departure_id, :agency_id
      ],
      name: "deposit_contributor_links_contributor_fk"

    add_check_constraint :supplier_deposit_requirement_definition_contributor_links,
      "position > 0", name: "deposit_contributor_links_position_positive"
    add_check_constraint :supplier_deposit_requirement_definition_contributor_links,
      "contributor_definition_id <> supplier_deposit_requirement_definition_id",
      name: "deposit_contributor_links_not_self"

    execute <<~SQL
      DROP TRIGGER IF EXISTS supplier_deposit_requirement_definition_contributor_links_reject_n
        ON public.supplier_deposit_requirement_definition_contributor_links;
      CREATE TRIGGER supplier_deposit_requirement_definition_contributor_links_reject_n
        BEFORE INSERT OR UPDATE OR DELETE ON public.supplier_deposit_requirement_definition_contributor_links
        FOR EACH ROW EXECUTE FUNCTION reject_non_draft_arrangement_version_definition_mutation();
    SQL
  end

  def amount_fields_sql
    "(" \
      "amount_shape = 'fixed_amount' AND fixed_amount_minor_units IS NOT NULL " \
      "AND fixed_amount_minor_units >= 0 AND rate_minor_units IS NULL " \
      "AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND percentage IS NULL AND rounding_scope IS NULL AND target_amount_minor_units IS NULL" \
    ") OR (" \
      "amount_shape = 'quantity_times_rate' AND rate_minor_units IS NOT NULL " \
      "AND rate_minor_units >= 0 AND quantity_basis IS NOT NULL " \
      "AND fixed_amount_minor_units IS NULL AND percentage IS NULL " \
      "AND rounding_scope IS NULL AND target_amount_minor_units IS NULL " \
      "AND ((quantity_basis = 'explicit' AND explicit_quantity IS NOT NULL AND explicit_quantity > 0) OR " \
      "(quantity_basis <> 'explicit' AND explicit_quantity IS NULL))" \
    ") OR (" \
      "amount_shape = 'percentage_of_cost_sources' AND percentage IS NOT NULL AND percentage > 0 " \
      "AND rounding_scope IS NOT NULL AND fixed_amount_minor_units IS NULL " \
      "AND rate_minor_units IS NULL AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND target_amount_minor_units IS NULL" \
    ") OR (" \
      "amount_shape = 'cumulative_target' AND target_amount_minor_units IS NOT NULL " \
      "AND target_amount_minor_units >= 0 AND fixed_amount_minor_units IS NULL " \
      "AND rate_minor_units IS NULL AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND percentage IS NULL AND rounding_scope IS NULL" \
    ") OR (" \
      "amount_shape = 'cumulative_target' AND target_amount_minor_units IS NULL " \
      "AND rate_minor_units IS NOT NULL AND rate_minor_units >= 0 " \
      "AND quantity_basis = 'capacity_pool_units' AND explicit_quantity IS NULL " \
      "AND fixed_amount_minor_units IS NULL AND percentage IS NULL AND rounding_scope IS NULL" \
    ")"
  end

  def legacy_amount_fields_sql
    "(" \
      "amount_shape = 'fixed_amount' AND fixed_amount_minor_units IS NOT NULL " \
      "AND fixed_amount_minor_units >= 0 AND rate_minor_units IS NULL " \
      "AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND percentage IS NULL AND rounding_scope IS NULL AND target_amount_minor_units IS NULL" \
    ") OR (" \
      "amount_shape = 'quantity_times_rate' AND rate_minor_units IS NOT NULL " \
      "AND rate_minor_units >= 0 AND quantity_basis IS NOT NULL " \
      "AND fixed_amount_minor_units IS NULL AND percentage IS NULL " \
      "AND rounding_scope IS NULL AND target_amount_minor_units IS NULL " \
      "AND ((quantity_basis = 'explicit' AND explicit_quantity IS NOT NULL AND explicit_quantity > 0) OR " \
      "(quantity_basis <> 'explicit' AND explicit_quantity IS NULL))" \
    ") OR (" \
      "amount_shape = 'percentage_of_cost_sources' AND percentage IS NOT NULL AND percentage > 0 " \
      "AND rounding_scope IS NOT NULL AND fixed_amount_minor_units IS NULL " \
      "AND rate_minor_units IS NULL AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND target_amount_minor_units IS NULL" \
    ") OR (" \
      "amount_shape = 'cumulative_target' AND target_amount_minor_units IS NOT NULL " \
      "AND target_amount_minor_units >= 0 AND fixed_amount_minor_units IS NULL " \
      "AND rate_minor_units IS NULL AND quantity_basis IS NULL AND explicit_quantity IS NULL " \
      "AND percentage IS NULL AND rounding_scope IS NULL" \
    ")"
  end

  def sql_list(values)
    values.map { |value| ActiveRecord::Base.connection.quote(value) }.join(", ")
  end
end
