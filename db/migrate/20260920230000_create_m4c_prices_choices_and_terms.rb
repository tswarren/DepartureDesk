# frozen_string_literal: true

class CreateM4cPricesChoicesAndTerms < ActiveRecord::Migration[8.1]
  def up
    create_package_prices
    add_choice_gated_membership
    create_choice_tables
    add_window_and_caps
    create_term_tables
    attach_freeze_triggers
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS package_client_term_resolutions_reject_non_draft_mutation ON public.package_client_term_resolutions;
      DROP TRIGGER IF EXISTS package_client_stated_conditions_reject_non_draft_mutation ON public.package_client_stated_conditions;
      DROP TRIGGER IF EXISTS package_client_cancellation_tiers_reject_non_draft_mutation ON public.package_client_cancellation_tiers;
      DROP TRIGGER IF EXISTS package_client_cancellation_policies_reject_non_draft_mutation ON public.package_client_cancellation_policies;
      DROP TRIGGER IF EXISTS package_client_payment_schedule_lines_reject_non_draft_mutation ON public.package_client_payment_schedule_lines;
      DROP TRIGGER IF EXISTS package_client_payment_schedules_reject_non_draft_mutation ON public.package_client_payment_schedules;
      DROP TRIGGER IF EXISTS service_offer_client_stated_conditions_reject_non_draft_mutation ON public.service_offer_client_stated_conditions;
      DROP TRIGGER IF EXISTS service_offer_client_cancellation_tiers_reject_non_draft_mutation ON public.service_offer_client_cancellation_tiers;
      DROP TRIGGER IF EXISTS service_offer_client_cancellation_policies_reject_non_draft_mutation ON public.service_offer_client_cancellation_policies;
      DROP TRIGGER IF EXISTS service_offer_client_payment_schedule_lines_reject_non_draft_mutation ON public.service_offer_client_payment_schedule_lines;
      DROP TRIGGER IF EXISTS service_offer_client_payment_schedules_reject_non_draft_mutation ON public.service_offer_client_payment_schedules;
      DROP TRIGGER IF EXISTS service_offer_choice_option_source_activations_reject_non_draft_mutation ON public.service_offer_choice_option_source_activations;
      DROP TRIGGER IF EXISTS service_offer_choice_options_reject_non_draft_mutation ON public.service_offer_choice_options;
      DROP TRIGGER IF EXISTS service_offer_choice_groups_reject_non_draft_mutation ON public.service_offer_choice_groups;
      DROP TRIGGER IF EXISTS package_price_component_bases_reject_non_draft_mutation ON public.package_price_component_bases;
      DROP TRIGGER IF EXISTS package_price_components_reject_non_draft_mutation ON public.package_price_components;
      DROP TRIGGER IF EXISTS package_price_definitions_reject_non_draft_mutation ON public.package_price_definitions;
    SQL
    drop_table :package_client_term_resolutions
    drop_table :package_client_stated_conditions
    drop_table :package_client_cancellation_tiers
    drop_table :package_client_cancellation_policies
    drop_table :package_client_payment_schedule_lines
    drop_table :package_client_payment_schedules
    drop_table :service_offer_client_stated_conditions
    drop_table :service_offer_client_cancellation_tiers
    drop_table :service_offer_client_cancellation_policies
    drop_table :service_offer_client_payment_schedule_lines
    drop_table :service_offer_client_payment_schedules
    remove_column :service_offer_versions, :sales_cap_quantity
    remove_column :service_offer_versions, :sales_cap_basis
    remove_column :package_versions, :sales_starts_on
    remove_column :package_versions, :sales_ends_on
    remove_column :package_versions, :sales_cap_quantity
    remove_column :package_versions, :sales_cap_basis
    drop_table :service_offer_choice_option_source_activations
    drop_table :service_offer_choice_options
    drop_table :service_offer_choice_groups
    remove_check_constraint :service_offer_source_bindings, name: "service_offer_source_bindings_alternative_group"
    remove_check_constraint :service_offer_source_bindings, name: "service_offer_source_bindings_membership_kind"
    add_check_constraint :service_offer_source_bindings,
      "membership_kind IN ('required', 'alternative')",
      name: "service_offer_source_bindings_membership_kind"
    add_check_constraint :service_offer_source_bindings,
      "(membership_kind = 'required' AND alternative_group_key IS NULL AND alternative_group_label IS NULL) OR " \
      "(membership_kind = 'alternative' AND alternative_group_key IS NOT NULL AND alternative_group_label IS NOT NULL)",
      name: "service_offer_source_bindings_alternative_group"
    drop_table :package_price_component_bases
    drop_table :package_price_components
    drop_table :package_price_definitions
  end

  private

  def create_package_prices
    create_table :package_price_definitions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.uuid :package_version_id, null: false
      table.string :currency, null: false, limit: 3
      table.string :mode, null: false
      table.string :rounding_mode, null: false, default: "half_up"
      table.decimal :single_occupancy_supplement_rate, precision: 20, scale: 10
      table.timestamps null: false
    end
    add_index :package_price_definitions, :package_version_id, unique: true,
      name: "index_package_price_definitions_one_per_version"
    add_index :package_price_definitions,
      [ :id, :package_version_id, :package_id, :departure_id, :agency_id ],
      unique: true, name: "index_package_price_definitions_on_full_owner"
    add_foreign_key :package_price_definitions, :package_versions,
      column: [ :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_id, :departure_id, :agency_id ],
      name: "package_price_definitions_version_fk"
    add_foreign_key :package_price_definitions, :departures,
      column: [ :departure_id, :agency_id, :currency ],
      primary_key: [ :id, :agency_id, :operating_currency ],
      name: "package_price_definitions_departure_currency_fk"
    add_check_constraint :package_price_definitions, "currency ~ '^[A-Z]{3}$'",
      name: "package_price_definitions_currency"
    add_check_constraint :package_price_definitions, "mode IN ('bundled', 'service_sum')",
      name: "package_price_definitions_mode"
    add_check_constraint :package_price_definitions, "rounding_mode = 'half_up'",
      name: "package_price_definitions_rounding"
    add_check_constraint :package_price_definitions,
      "(mode = 'bundled') OR (single_occupancy_supplement_rate IS NULL)",
      name: "package_price_definitions_supplement_mode"
    add_check_constraint :package_price_definitions,
      "single_occupancy_supplement_rate IS NULL OR single_occupancy_supplement_rate >= 0",
      name: "package_price_definitions_supplement_nonnegative"

    create_table :package_price_components, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.uuid :package_version_id, null: false
      table.uuid :package_price_definition_id, null: false
      table.string :label, null: false, limit: 160
      table.string :client_role, null: false
      table.string :calculation_kind, null: false
      table.bigint :amount_minor_units
      table.decimal :rate, precision: 20, scale: 10
      table.string :quantity_basis
      table.string :percentage_treatment
      table.integer :position, null: false
      table.timestamps null: false
    end
    add_index :package_price_components, [ :package_price_definition_id, :position ],
      unique: true, name: "index_package_price_components_on_position"
    add_index :package_price_components,
      [ :id, :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      unique: true, name: "index_package_price_components_on_full_owner"
    add_foreign_key :package_price_components, :package_price_definitions,
      column: [ :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_version_id, :package_id, :departure_id, :agency_id ],
      name: "package_price_components_definition_fk"
    add_check_constraint :package_price_components,
      "client_role IN ('base_price', 'named_discount', 'named_surcharge', 'tax_fee')",
      name: "package_price_components_role"
    add_check_constraint :package_price_components,
      "calculation_kind IN ('fixed', 'unit_rate', 'percentage')",
      name: "package_price_components_kind"
    add_check_constraint :package_price_components, "position > 0",
      name: "package_price_components_position"
    add_check_constraint :package_price_components,
      "amount_minor_units IS NULL OR amount_minor_units >= 0",
      name: "package_price_components_amount"
    add_check_constraint :package_price_components, "rate IS NULL OR rate >= 0",
      name: "package_price_components_rate"

    create_table :package_price_component_bases, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.uuid :package_version_id, null: false
      table.uuid :package_price_definition_id, null: false
      table.uuid :package_price_component_id, null: false
      table.uuid :base_component_id, null: false
      table.string :direction, null: false
      table.integer :position, null: false
      table.timestamps null: false
    end
    add_index :package_price_component_bases, [ :package_price_component_id, :base_component_id ],
      unique: true, name: "index_package_price_component_bases_on_pair"
    add_foreign_key :package_price_component_bases, :package_price_components,
      column: [ :package_price_component_id, :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      name: "package_price_component_bases_component_fk"
    add_foreign_key :package_price_component_bases, :package_price_components,
      column: [ :base_component_id, :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_price_definition_id, :package_version_id, :package_id, :departure_id, :agency_id ],
      name: "package_price_component_bases_base_fk"
    add_check_constraint :package_price_component_bases, "direction IN ('add', 'subtract')",
      name: "package_price_component_bases_direction"
    add_check_constraint :package_price_component_bases, "position > 0",
      name: "package_price_component_bases_position"
  end

  def add_choice_gated_membership
    remove_check_constraint :service_offer_source_bindings, name: "service_offer_source_bindings_alternative_group"
    remove_check_constraint :service_offer_source_bindings, name: "service_offer_source_bindings_membership_kind"
    add_check_constraint :service_offer_source_bindings,
      "membership_kind IN ('required', 'alternative', 'choice_gated')",
      name: "service_offer_source_bindings_membership_kind"
    add_check_constraint :service_offer_source_bindings,
      "(membership_kind IN ('required', 'choice_gated') AND alternative_group_key IS NULL AND alternative_group_label IS NULL) OR " \
      "(membership_kind = 'alternative' AND alternative_group_key IS NOT NULL AND alternative_group_label IS NOT NULL)",
      name: "service_offer_source_bindings_alternative_group"
    add_index :service_offer_source_bindings,
      [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_source_bindings_on_full_owner"
  end

  def create_choice_tables
    create_table :service_offer_choice_groups, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :name, null: false, limit: 160
      table.integer :min_selections, null: false, default: 0
      table.integer :max_selections, null: false, default: 1
      table.integer :position, null: false
      table.timestamps null: false
    end
    add_index :service_offer_choice_groups, [ :service_offer_version_id, :position ],
      unique: true, name: "index_service_offer_choice_groups_on_position"
    add_index :service_offer_choice_groups,
      [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_choice_groups_on_full_owner"
    add_foreign_key :service_offer_choice_groups, :service_offer_versions,
      column: [ :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_choice_groups_version_fk"
    add_check_constraint :service_offer_choice_groups,
      "min_selections >= 0 AND max_selections >= min_selections",
      name: "service_offer_choice_groups_bounds"
    add_check_constraint :service_offer_choice_groups, "position > 0",
      name: "service_offer_choice_groups_position"

    create_table :service_offer_choice_options, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.uuid :service_offer_choice_group_id, null: false
      table.string :name, null: false, limit: 160
      table.string :client_description, limit: 2_000
      table.bigint :price_effect_minor_units
      table.integer :position, null: false
      table.timestamps null: false
    end
    add_index :service_offer_choice_options, [ :service_offer_choice_group_id, :position ],
      unique: true, name: "index_service_offer_choice_options_on_position"
    add_index :service_offer_choice_options,
      [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      unique: true, name: "index_service_offer_choice_options_on_full_owner"
    add_foreign_key :service_offer_choice_options, :service_offer_choice_groups,
      column: [ :service_offer_choice_group_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_choice_options_group_fk"
    add_check_constraint :service_offer_choice_options, "position > 0",
      name: "service_offer_choice_options_position"
    add_check_constraint :service_offer_choice_options,
      "price_effect_minor_units IS NULL OR price_effect_minor_units >= 0",
      name: "service_offer_choice_options_price_effect"

    create_table :service_offer_choice_option_source_activations, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :service_offer_id, null: false
      table.uuid :service_offer_version_id, null: false
      table.uuid :service_offer_choice_option_id, null: false
      table.string :activation_kind, null: false
      table.uuid :service_offer_source_binding_id
      table.string :alternative_group_key, limit: 80
      table.timestamps null: false
    end
    add_index :service_offer_choice_option_source_activations, :service_offer_choice_option_id,
      unique: true, name: "index_service_offer_choice_activations_one_per_option"
    add_foreign_key :service_offer_choice_option_source_activations, :service_offer_choice_options,
      column: [ :service_offer_choice_option_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_choice_activations_option_fk"
    add_foreign_key :service_offer_choice_option_source_activations, :service_offer_source_bindings,
      column: [ :service_offer_source_binding_id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      primary_key: [ :id, :service_offer_version_id, :service_offer_id, :departure_id, :agency_id ],
      name: "service_offer_choice_activations_binding_fk"
    add_check_constraint :service_offer_choice_option_source_activations,
      "activation_kind IN ('binding', 'alternative_group', 'none')",
      name: "service_offer_choice_activations_kind"
    add_check_constraint :service_offer_choice_option_source_activations, <<~SQL.squish,
      (activation_kind = 'binding' AND service_offer_source_binding_id IS NOT NULL AND alternative_group_key IS NULL)
      OR (activation_kind = 'alternative_group' AND alternative_group_key IS NOT NULL AND service_offer_source_binding_id IS NULL)
      OR (activation_kind = 'none' AND service_offer_source_binding_id IS NULL AND alternative_group_key IS NULL)
    SQL
      name: "service_offer_choice_activations_shape"
  end

  def add_window_and_caps
    add_column :package_versions, :sales_starts_on, :date
    add_column :package_versions, :sales_ends_on, :date
    add_column :package_versions, :sales_cap_quantity, :integer
    add_column :package_versions, :sales_cap_basis, :string
    add_check_constraint :package_versions,
      "(sales_starts_on IS NULL) = (sales_ends_on IS NULL)",
      name: "package_versions_sales_window_pair"
    add_check_constraint :package_versions,
      "sales_starts_on IS NULL OR sales_starts_on <= sales_ends_on",
      name: "package_versions_sales_window_order"
    add_check_constraint :package_versions,
      "(sales_cap_quantity IS NULL) = (sales_cap_basis IS NULL)",
      name: "package_versions_sales_cap_pair"
    add_check_constraint :package_versions,
      "sales_cap_quantity IS NULL OR sales_cap_quantity > 0",
      name: "package_versions_sales_cap_quantity"
    add_check_constraint :package_versions,
      "sales_cap_basis IS NULL OR sales_cap_basis IN ('package_bookings', 'persons', 'resource_units')",
      name: "package_versions_sales_cap_basis"

    add_column :service_offer_versions, :sales_cap_quantity, :integer
    add_column :service_offer_versions, :sales_cap_basis, :string
    add_check_constraint :service_offer_versions,
      "(sales_cap_quantity IS NULL) = (sales_cap_basis IS NULL)",
      name: "service_offer_versions_sales_cap_pair"
    add_check_constraint :service_offer_versions,
      "sales_cap_quantity IS NULL OR sales_cap_quantity > 0",
      name: "service_offer_versions_sales_cap_quantity"
    add_check_constraint :service_offer_versions,
      "sales_cap_basis IS NULL OR sales_cap_basis IN ('persons', 'resource_units')",
      name: "service_offer_versions_sales_cap_basis"
  end

  def create_term_tables
    create_payment_family("package")
    create_payment_family("service_offer")
    create_cancellation_family("package")
    create_cancellation_family("service_offer")
    create_stated_family("package")
    create_stated_family("service_offer")

    create_table :package_client_term_resolutions, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid :package_id, null: false
      table.uuid :package_version_id, null: false
      table.string :kind, null: false
      table.uuid :service_offer_version_id, null: false
      table.string :governing_side, null: false
      table.string :reason, null: false, limit: 500
      table.timestamps null: false
    end
    add_index :package_client_term_resolutions,
      [ :package_version_id, :kind, :service_offer_version_id ],
      unique: true, name: "index_package_client_term_resolutions_unique"
    add_foreign_key :package_client_term_resolutions, :package_versions,
      column: [ :package_version_id, :package_id, :departure_id, :agency_id ],
      primary_key: [ :id, :package_id, :departure_id, :agency_id ],
      name: "package_client_term_resolutions_version_fk"
    add_foreign_key :package_client_term_resolutions, :service_offer_versions,
      column: [ :service_offer_version_id, :departure_id, :agency_id ],
      primary_key: [ :id, :departure_id, :agency_id ],
      name: "package_client_term_resolutions_offer_version_fk"
    add_check_constraint :package_client_term_resolutions,
      "kind IN ('payment', 'cancellation', 'stated_condition')",
      name: "package_client_term_resolutions_kind"
    add_check_constraint :package_client_term_resolutions,
      "governing_side IN ('package', 'service')",
      name: "package_client_term_resolutions_side"
    add_check_constraint :package_client_term_resolutions,
      "btrim(reason) <> ''",
      name: "package_client_term_resolutions_reason"
  end

  def create_payment_family(owner)
    header = "#{owner}_client_payment_schedules"
    lines = "#{owner}_client_payment_schedule_lines"
    version = "#{owner}_version"
    parent = owner == "package" ? "package" : "service_offer"

    create_table header.to_sym, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid "#{parent}_id", null: false
      table.uuid "#{version}_id", null: false
      table.timestamps null: false
    end
    add_index header, "#{version}_id", unique: true, name: "idx_#{owner}_pay_one_ver"
    add_index header, [ :id, "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      unique: true, name: "idx_#{owner}_pay_full_own"
    add_foreign_key header, "#{owner}_versions",
      column: [ "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      primary_key: [ :id, "#{parent}_id", :departure_id, :agency_id ],
      name: "#{header}_version_fk"

    create_table lines.to_sym, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid "#{parent}_id", null: false
      table.uuid "#{version}_id", null: false
      table.uuid "#{owner}_client_payment_schedule_id", null: false
      table.integer :position, null: false
      table.string :due_kind, null: false
      table.date :due_on
      table.string :milestone_name, limit: 160
      table.string :amount_kind, null: false
      table.bigint :amount_minor_units
      table.decimal :percent_rate, precision: 20, scale: 10
      table.string :percent_base
      table.timestamps null: false
    end
    add_index lines, [ "#{owner}_client_payment_schedule_id", :position ],
      unique: true, name: "idx_#{owner}_pay_lines_pos"
    add_foreign_key lines, header,
      column: [ "#{owner}_client_payment_schedule_id", "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      primary_key: [ :id, "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      name: "#{lines}_schedule_fk"
    add_check_constraint lines, "due_kind IN ('fixed_on', 'named_relative_milestone')",
      name: "#{lines}_due_kind"
    add_check_constraint lines, <<~SQL.squish,
      (due_kind = 'fixed_on' AND due_on IS NOT NULL AND milestone_name IS NULL)
      OR (due_kind = 'named_relative_milestone' AND milestone_name IS NOT NULL AND due_on IS NULL)
    SQL
      name: "#{lines}_due_shape"
    add_check_constraint lines, "amount_kind IN ('fixed', 'percent')", name: "#{lines}_amount_kind"
    add_check_constraint lines, <<~SQL.squish,
      (amount_kind = 'fixed' AND amount_minor_units IS NOT NULL AND percent_rate IS NULL AND percent_base IS NULL)
      OR (amount_kind = 'percent' AND percent_rate IS NOT NULL AND percent_base = 'selected_client_price' AND amount_minor_units IS NULL)
    SQL
      name: "#{lines}_amount_shape"
  end

  def create_cancellation_family(owner)
    header = "#{owner}_client_cancellation_policies"
    tiers = "#{owner}_client_cancellation_tiers"
    version = "#{owner}_version"
    parent = owner == "package" ? "package" : "service_offer"

    create_table header.to_sym, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid "#{parent}_id", null: false
      table.uuid "#{version}_id", null: false
      table.timestamps null: false
    end
    add_index header, "#{version}_id", unique: true, name: "idx_#{owner}_can_one_ver"
    add_index header, [ :id, "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      unique: true, name: "idx_#{owner}_can_full_own"
    add_foreign_key header, "#{owner}_versions",
      column: [ "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      primary_key: [ :id, "#{parent}_id", :departure_id, :agency_id ],
      name: "#{header}_version_fk"

    create_table tiers.to_sym, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid "#{parent}_id", null: false
      table.uuid "#{version}_id", null: false
      table.uuid "#{owner}_client_cancellation_policy_id", null: false
      table.integer :position, null: false
      table.string :threshold_kind, null: false
      table.date :threshold_on
      table.integer :days_before
      table.string :consequence_kind, null: false
      table.bigint :amount_minor_units
      table.decimal :percent_rate, precision: 20, scale: 10
      table.string :percent_base
      table.string :summary, limit: 2_000
      table.timestamps null: false
    end
    add_index tiers, [ "#{owner}_client_cancellation_policy_id", :position ],
      unique: true, name: "idx_#{owner}_cancel_tiers_pos"
    add_foreign_key tiers, header,
      column: [ "#{owner}_client_cancellation_policy_id", "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      primary_key: [ :id, "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      name: "#{tiers}_policy_fk"
    add_check_constraint tiers, "threshold_kind IN ('on_or_before_date', 'days_before_departure')",
      name: "#{tiers}_threshold_kind"
    add_check_constraint tiers, <<~SQL.squish,
      (threshold_kind = 'on_or_before_date' AND threshold_on IS NOT NULL AND days_before IS NULL)
      OR (threshold_kind = 'days_before_departure' AND days_before IS NOT NULL AND days_before >= 0 AND threshold_on IS NULL)
    SQL
      name: "#{tiers}_threshold_shape"
    add_check_constraint tiers, "consequence_kind IN ('fixed', 'percent', 'manual_review')",
      name: "#{tiers}_consequence_kind"
    add_check_constraint tiers, <<~SQL.squish,
      (consequence_kind = 'fixed' AND amount_minor_units IS NOT NULL AND percent_rate IS NULL AND percent_base IS NULL AND summary IS NULL)
      OR (consequence_kind = 'percent' AND percent_rate IS NOT NULL AND percent_base = 'selected_client_price' AND amount_minor_units IS NULL AND summary IS NULL)
      OR (consequence_kind = 'manual_review' AND summary IS NOT NULL AND btrim(summary) <> '' AND amount_minor_units IS NULL AND percent_rate IS NULL AND percent_base IS NULL)
    SQL
      name: "#{tiers}_consequence_shape"
  end

  def create_stated_family(owner)
    table_name = "#{owner}_client_stated_conditions"
    version = "#{owner}_version"
    parent = owner == "package" ? "package" : "service_offer"
    create_table table_name.to_sym, id: :uuid, default: -> { "uuidv7()" } do |table|
      table.references :agency, null: false, type: :uuid, foreign_key: true
      table.uuid :departure_id, null: false
      table.uuid "#{parent}_id", null: false
      table.uuid "#{version}_id", null: false
      table.integer :position, null: false
      table.string :condition_kind, null: false
      table.string :body, null: false, limit: 2_000
      table.timestamps null: false
    end
    add_index table_name, [ "#{version}_id", :position ], unique: true, name: "idx_#{owner}_stated_pos"
    add_foreign_key table_name, "#{owner}_versions",
      column: [ "#{version}_id", "#{parent}_id", :departure_id, :agency_id ],
      primary_key: [ :id, "#{parent}_id", :departure_id, :agency_id ],
      name: "#{table_name}_version_fk"
    add_check_constraint table_name, "condition_kind IN ('eligibility', 'acknowledgment')",
      name: "#{table_name}_kind"
    add_check_constraint table_name, "btrim(body) <> ''", name: "#{table_name}_body"
  end

  def attach_freeze_triggers
    package_tables = %w[
      package_price_definitions package_price_components package_price_component_bases
      package_client_payment_schedules package_client_payment_schedule_lines
      package_client_cancellation_policies package_client_cancellation_tiers
      package_client_stated_conditions package_client_term_resolutions
    ]
    offer_tables = %w[
      service_offer_choice_groups service_offer_choice_options
      service_offer_choice_option_source_activations
      service_offer_client_payment_schedules service_offer_client_payment_schedule_lines
      service_offer_client_cancellation_policies service_offer_client_cancellation_tiers
      service_offer_client_stated_conditions
    ]
    package_tables.each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_non_draft_mutation
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_non_draft_package_version_definition_mutation();
      SQL
    end
    offer_tables.each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_reject_non_draft_mutation
          BEFORE INSERT OR UPDATE OR DELETE ON public.#{table}
          FOR EACH ROW EXECUTE FUNCTION reject_non_draft_service_offer_version_definition_mutation();
      SQL
    end
  end
end
