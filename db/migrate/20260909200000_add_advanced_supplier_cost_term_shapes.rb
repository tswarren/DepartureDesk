class AddAdvancedSupplierCostTermShapes < ActiveRecord::Migration[8.1]
  SHAPES = %w[
    fixed per_resource per_person per_night minimum_guarantee
    tiered stepped percentage complimentary_ratio pass_through
    manual_estimate
  ].freeze
  PREVIOUS_SHAPES = %w[fixed per_resource per_person per_night minimum_guarantee manual_estimate].freeze

  def up
    update_shape_check(SHAPES)
    create_tiers
    create_steps
    create_percentage_base_refs
    create_complimentary_ratio_rules
    create_pass_through_provenances
  end

  def down
    drop_table :supplier_cost_term_pass_through_provenances
    drop_table :supplier_cost_term_complimentary_ratio_rules
    drop_table :supplier_cost_term_percentage_base_refs
    drop_table :supplier_cost_term_steps
    drop_table :supplier_cost_term_tiers
    update_shape_check(PREVIOUS_SHAPES)
  end

  private

  def create_tiers
    create_table :supplier_cost_term_tiers, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.integer :threshold_quantity, null: false
      table.bigint :unit_amount_minor_units, null: false
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_tiers, "sct_tiers")
    add_index :supplier_cost_term_tiers, [ :supplier_cost_term_id, :threshold_quantity ], unique: true, name: "index_sct_tiers_on_term_and_threshold"
    add_check_constraint :supplier_cost_term_tiers, "threshold_quantity > 0", name: "sct_tiers_threshold_positive"
    add_check_constraint :supplier_cost_term_tiers, "unit_amount_minor_units >= 0", name: "sct_tiers_amount_nonnegative"
  end

  def create_steps
    create_table :supplier_cost_term_steps, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.integer :band_start_quantity, null: false
      table.integer :band_end_quantity
      table.bigint :unit_amount_minor_units, null: false
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_steps, "sct_steps")
    add_check_constraint :supplier_cost_term_steps, "band_start_quantity > 0", name: "sct_steps_start_positive"
    add_check_constraint :supplier_cost_term_steps, "band_end_quantity IS NULL OR band_end_quantity >= band_start_quantity", name: "sct_steps_end_after_start"
    add_check_constraint :supplier_cost_term_steps, "unit_amount_minor_units >= 0", name: "sct_steps_amount_nonnegative"
    execute <<~SQL
      ALTER TABLE supplier_cost_term_steps
        ADD CONSTRAINT sct_steps_no_overlapping_bands
        EXCLUDE USING gist (
          supplier_cost_term_id WITH =,
          int4range(band_start_quantity, COALESCE(band_end_quantity, 2147483647), '[]') WITH &&
        );
    SQL
  end

  def create_percentage_base_refs
    create_table :supplier_cost_term_percentage_base_refs, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.integer :rate_basis_points, null: false
      table.uuid :base_economic_item_id
      table.string :base_economic_item_key
      table.bigint :base_amount_minor_units
      table.string :base_reference, null: false
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_percentage_base_refs, "sct_percentage_refs", unique_term: true)
    add_check_constraint :supplier_cost_term_percentage_base_refs, "rate_basis_points >= 0", name: "sct_percentage_refs_rate_nonnegative"
    add_check_constraint :supplier_cost_term_percentage_base_refs, "base_amount_minor_units IS NULL OR base_amount_minor_units >= 0", name: "sct_percentage_refs_amount_nonnegative"
    add_check_constraint :supplier_cost_term_percentage_base_refs,
      "base_amount_minor_units IS NOT NULL OR base_economic_item_id IS NOT NULL OR COALESCE(btrim(base_economic_item_key), '') <> ''",
      name: "sct_percentage_refs_base_present"
    add_check_constraint :supplier_cost_term_percentage_base_refs, "btrim(base_reference) <> ''", name: "sct_percentage_refs_reference_not_blank"
  end

  def create_complimentary_ratio_rules
    create_table :supplier_cost_term_complimentary_ratio_rules, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.integer :minimum_qualifying_quantity, null: false, default: 1
      table.integer :paid_unit_quantity, null: false
      table.integer :complimentary_unit_quantity, null: false
      table.bigint :unit_amount_minor_units, null: false
      table.string :rounding_rule, null: false, default: "floor"
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_complimentary_ratio_rules, "sct_comp_ratio_rules")
    add_index :supplier_cost_term_complimentary_ratio_rules,
      [ :supplier_cost_term_id, :minimum_qualifying_quantity ],
      unique: true,
      name: "index_sct_comp_rules_on_term_and_min_qty"
    add_check_constraint :supplier_cost_term_complimentary_ratio_rules, "minimum_qualifying_quantity > 0", name: "sct_comp_rules_minimum_positive"
    add_check_constraint :supplier_cost_term_complimentary_ratio_rules, "paid_unit_quantity > 0", name: "sct_comp_rules_paid_positive"
    add_check_constraint :supplier_cost_term_complimentary_ratio_rules, "complimentary_unit_quantity > 0", name: "sct_comp_rules_comp_positive"
    add_check_constraint :supplier_cost_term_complimentary_ratio_rules, "unit_amount_minor_units >= 0", name: "sct_comp_rules_amount_nonnegative"
    add_check_constraint :supplier_cost_term_complimentary_ratio_rules, "rounding_rule IN ('floor', 'ceiling', 'nearest')", name: "sct_comp_rules_rounding_valid"
  end

  def create_pass_through_provenances
    create_table :supplier_cost_term_pass_through_provenances, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :supplier_cost_term_id, null: false
      table.bigint :supplier_amount_minor_units, null: false
      table.string :supplier_amount_reference, null: false
      table.text :provenance, null: false
      table.timestamps null: false
    end
    add_detail_indexes_and_fk(:supplier_cost_term_pass_through_provenances, "sct_pass_throughs", unique_term: true)
    add_check_constraint :supplier_cost_term_pass_through_provenances, "supplier_amount_minor_units >= 0", name: "sct_pass_throughs_amount_nonnegative"
    add_check_constraint :supplier_cost_term_pass_through_provenances, "btrim(supplier_amount_reference) <> ''", name: "sct_pass_throughs_reference_not_blank"
    add_check_constraint :supplier_cost_term_pass_through_provenances, "btrim(provenance) <> ''", name: "sct_pass_throughs_provenance_not_blank"
  end

  def update_shape_check(shapes)
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_shape_valid"
    quoted_shapes = shapes.map { |shape| connection.quote(shape) }.join(", ")
    add_check_constraint :supplier_cost_terms, "shape IN (#{quoted_shapes})", name: "supplier_cost_terms_shape_valid"
  end

  def add_detail_indexes_and_fk(table_name, short_name, unique_term: false)
    add_index table_name, [ :supplier_cost_term_id, :agency_id ], unique: unique_term, name: "index_#{short_name}_on_term_and_agency"
    execute <<~SQL
      ALTER TABLE #{table_name}
        ADD CONSTRAINT #{short_name}_term_fk
        FOREIGN KEY (supplier_cost_term_id, agency_id)
        REFERENCES supplier_cost_terms (id, agency_id);
    SQL
  end
end
