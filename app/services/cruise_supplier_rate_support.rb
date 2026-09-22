# frozen_string_literal: true

# Shared Cruise Supplier-rate matrix vocabulary for Slice 2A.2R.
# Rate profiles are columns; component rows are charges/credits; cells compile to
# generic SupplierCostComponent records. No Cruise-specific persistence.
module CruiseSupplierRateSupport
  PARTICIPANT_CATEGORY_LABEL = "Traveler"
  COMMISSION_LABEL = "Expected commission"
  COMMISSION_METHODS = %w[not_provided dollar percentage].freeze

  STATIC_ROWS = {
    base_fare: { label: "Base Fare", economic_role: "supplier_charge" },
    nccf: { label: "NCCF", economic_role: "supplier_charge" },
    taxes_fees: { label: "Taxes & Fees", economic_role: "supplier_charge" },
    discount: { label: "Discount", economic_role: "supplier_credit" }
  }.freeze

  PROFILE_FAMILIES = {
    first_second: {
      label: "First/Second",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 1,
      occupancy_position_to: 2
    },
    additional: {
      label: "Additional",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 3,
      occupancy_position_to: nil
    },
    every_traveler: {
      label: "Every Traveler",
      quantity_basis: "persons",
      occupancy_position_from: nil,
      occupancy_position_to: nil
    },
    every_cabin: {
      label: "Every Cabin",
      quantity_basis: "resource_units",
      occupancy_position_from: nil,
      occupancy_position_to: nil
    },
    single_supplement: {
      label: "Single Supplement",
      quantity_basis: "single_occupancy_units",
      occupancy_position_from: nil,
      occupancy_position_to: nil
    }
  }.freeze

  # Shipped 2A.2 fixed-form labels → matrix cells (row_key, profile_key).
  LEGACY_LABEL_TO_CELL = {
    "First/second traveler fare" => %i[base_fare first_second],
    "Additional traveler fare" => %i[base_fare additional],
    "Single occupancy supplement" => %i[base_fare single_supplement],
    "NCCF" => %i[nccf every_traveler],
    "First/second traveler discount" => %i[discount first_second],
    "Additional traveler discount" => %i[discount additional],
    "Taxes, fees, and port charges" => %i[taxes_fees every_traveler]
  }.freeze

  LEGACY_ONLY_LABELS = (
    LEGACY_LABEL_TO_CELL.keys - STATIC_ROWS.values.map { |spec| spec.fetch(:label) }
  ).freeze

  OCCUPANCY_PROFILE_SPECS = {
    single: { label: "Single occupancy", positions: 1 },
    double: { label: "Double occupancy", positions: 2 },
    triple: { label: "Triple occupancy", positions: 3 }
  }.freeze

  module_function

  def static_row_keys
    STATIC_ROWS.keys
  end

  def profile_family_keys
    PROFILE_FAMILIES.keys
  end

  def static_row_label(key)
    STATIC_ROWS.fetch(key.to_sym).fetch(:label)
  end

  def static_row_role(key)
    STATIC_ROWS.fetch(key.to_sym).fetch(:economic_role)
  end

  def normalize_row_label(label)
    text = label.to_s.strip
    STATIC_ROWS.each_value do |spec|
      return spec.fetch(:label) if spec.fetch(:label).casecmp?(text)
    end
    text
  end

  def static_row_key_for_label(label)
    normalized = normalize_row_label(label)
    STATIC_ROWS.each do |key, spec|
      return key if spec.fetch(:label) == normalized
    end
    nil
  end

  def profile_key_for_component(component)
    PROFILE_FAMILIES.each do |key, spec|
      next unless component.quantity_basis == spec.fetch(:quantity_basis)
      next unless component.occupancy_position_from == spec[:occupancy_position_from]
      next unless component.occupancy_position_to == spec[:occupancy_position_to]
      next unless component.participant_category_id.nil?

      return key
    end
    nil
  end

  def cell_key(row_key, profile_key)
    "#{row_key}:#{profile_key}"
  end

  def parse_cell_key(key)
    row_key, profile_key = key.to_s.split(":", 2)
    [ row_key&.to_sym, profile_key&.to_sym ]
  end

  def occupancy_keys_for_maximum(maximum_occupancy)
    max = maximum_occupancy.to_i
    keys = []
    keys << :single if max >= 1
    keys << :double if max >= 2
    keys << :triple if max >= 3
    keys
  end

  def legacy_form?(components)
    charge_credit = components.reject { |c| c.economic_role == "expected_commission" }
    return false if charge_credit.empty?
    return false if matrix_form?(components)

    charge_credit.all? { |c| LEGACY_LABEL_TO_CELL.key?(c.label) }
  end

  def matrix_form?(components)
    charge_credit = components.reject { |c| c.economic_role == "expected_commission" }
    return false if charge_credit.empty?

    charge_credit.all? do |component|
      next false if LEGACY_ONLY_LABELS.include?(component.label)
      next false unless %w[supplier_charge supplier_credit].include?(component.economic_role)
      next false unless component.calculation_kind == "unit_rate"

      row_key = static_row_key_for_label(component.label)
      next false if row_key.nil?
      next false unless static_row_role(row_key) == component.economic_role

      profile_key_for_component(component).present?
    end
  end
end
