class LockSupplierPlanningVocabularies < ActiveRecord::Migration[8.1]
  COST_CATEGORIES = %w[
    coach coach_seat cabin cabin_guarantee room lodging hotel_block transport tour
    vineyard_lunch vineyard_seats guide_ticket park_permit supplier_fee supplier_guarantee insurance other
  ].freeze
  QUANTITY_BASES = %w[
    arrangement resource reservation occurrence planning_quantity guaranteed_quantity
    qualifying_quantity base_amount supplier_invoice
  ].freeze
  QUANTITY_UNITS = %w[
    seat room cabin vehicle policy unit contract coach person guest fee permit night
  ].freeze
  ROUNDING_METHODS = %w[nearest_minor_unit].freeze
  TAX_FEE_TREATMENTS = %w[included excluded separate].freeze
  RESOURCE_KINDS = %w[
    cabin_category room_type coach tour_inventory vehicle insurance_product other
  ].freeze
  IDENTIFIER_TYPES = %w[
    supplier_confirmation booking_reference pnr group_code allotment_code
  ].freeze
  CONTEXTS = %w[
    supplier_portal email phone fax document other
  ].freeze
  SEGMENT_TYPES = %w[
    sailing transfer tour_day optional_extension flight_segment other
  ].freeze

  def up
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_category_not_blank"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_quantity_basis_not_blank"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_quantity_unit_not_blank"

    add_check_constraint :supplier_cost_terms,
      "cost_category IN (#{quoted(COST_CATEGORIES)})",
      name: "supplier_cost_terms_cost_category_valid"
    add_check_constraint :supplier_cost_terms,
      "quantity_basis IN (#{quoted(QUANTITY_BASES)})",
      name: "supplier_cost_terms_quantity_basis_valid"
    add_check_constraint :supplier_cost_terms,
      "quantity_unit IN (#{quoted(QUANTITY_UNITS)})",
      name: "supplier_cost_terms_quantity_unit_valid"
    add_check_constraint :supplier_cost_terms,
      "rounding_method IN (#{quoted(ROUNDING_METHODS)})",
      name: "supplier_cost_terms_rounding_method_valid"
    add_check_constraint :supplier_cost_terms,
      "tax_fee_treatment IN (#{quoted(TAX_FEE_TREATMENTS)})",
      name: "supplier_cost_terms_tax_fee_treatment_valid"

    add_check_constraint :supplier_commitments,
      "cost_category IN (#{quoted(COST_CATEGORIES)})",
      name: "supplier_commitments_cost_category_valid"
    add_check_constraint :supplier_commitments,
      "quantity_basis IN (#{quoted(QUANTITY_BASES)})",
      name: "supplier_commitments_quantity_basis_valid"
    add_check_constraint :supplier_commitments,
      "quantity_unit IN (#{quoted(QUANTITY_UNITS)})",
      name: "supplier_commitments_quantity_unit_valid"

    add_check_constraint :supplier_resources,
      "resource_kind IN (#{quoted(RESOURCE_KINDS)})",
      name: "supplier_resources_resource_kind_valid"

    add_check_constraint :supplier_confirmations,
      "identifier_type IN (#{quoted(IDENTIFIER_TYPES)})",
      name: "supplier_confirmations_identifier_type_valid"
    add_check_constraint :supplier_confirmations,
      "context IN (#{quoted(CONTEXTS)})",
      name: "supplier_confirmations_context_valid"

    add_check_constraint :supplier_service_occurrences,
      "segment_type IS NULL OR segment_type IN (#{quoted(SEGMENT_TYPES)})",
      name: "supplier_service_occurrences_segment_type_valid"
  end

  def down
    remove_check_constraint :supplier_service_occurrences, name: "supplier_service_occurrences_segment_type_valid"
    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_context_valid"
    remove_check_constraint :supplier_confirmations, name: "supplier_confirmations_identifier_type_valid"
    remove_check_constraint :supplier_resources, name: "supplier_resources_resource_kind_valid"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_quantity_unit_valid"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_quantity_basis_valid"
    remove_check_constraint :supplier_commitments, name: "supplier_commitments_cost_category_valid"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_tax_fee_treatment_valid"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_rounding_method_valid"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_quantity_unit_valid"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_quantity_basis_valid"
    remove_check_constraint :supplier_cost_terms, name: "supplier_cost_terms_cost_category_valid"

    add_check_constraint :supplier_cost_terms, "btrim(cost_category) <> ''", name: "supplier_cost_terms_category_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(quantity_basis) <> ''", name: "supplier_cost_terms_quantity_basis_not_blank"
    add_check_constraint :supplier_cost_terms, "btrim(quantity_unit) <> ''", name: "supplier_cost_terms_quantity_unit_not_blank"
  end

  private

  def quoted(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
