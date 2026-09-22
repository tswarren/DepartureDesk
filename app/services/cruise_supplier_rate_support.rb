# frozen_string_literal: true

# Shared Cruise Supplier-rate vocabulary and builders for Slice 2A.2.
# Commands include CostCommandSupport and this module; the detector/preview
# include only the read-side constants and matchers.
module CruiseSupplierRateSupport
  PARTICIPANT_CATEGORY_LABEL = "Traveler"

  CANONICAL_TERM_KEYS = %i[
    first_second_fare
    additional_fare
    single_supplement
    nccf
    first_second_discount
    additional_discount
    taxes_fees
  ].freeze

  COMMISSION_METHODS = %w[not_provided dollar percentage].freeze
  DOLLAR_BASES = %w[persons resource_units].freeze

  CANONICAL_SPECS = {
    first_second_fare: {
      label: "First/second traveler fare",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 1,
      occupancy_position_to: 2
    },
    additional_fare: {
      label: "Additional traveler fare",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 3,
      occupancy_position_to: nil
    },
    single_supplement: {
      label: "Single occupancy supplement",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      quantity_basis: "single_occupancy_units"
    },
    nccf: {
      label: "NCCF",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      quantity_basis: "persons"
    },
    first_second_discount: {
      label: "First/second traveler discount",
      economic_role: "supplier_credit",
      calculation_kind: "unit_rate",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 1,
      occupancy_position_to: 2
    },
    additional_discount: {
      label: "Additional traveler discount",
      economic_role: "supplier_credit",
      calculation_kind: "unit_rate",
      quantity_basis: "occupancy_positions",
      occupancy_position_from: 3,
      occupancy_position_to: nil
    },
    taxes_fees: {
      label: "Taxes, fees, and port charges",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      quantity_basis: "persons"
    }
  }.freeze

  COMMISSION_LABEL = "Expected commission"

  CHARGE_BASE_KEYS = %i[first_second_fare additional_fare single_supplement nccf taxes_fees].freeze
  DISCOUNT_BASE_KEYS = %i[first_second_discount additional_discount].freeze

  SUGGESTED_PERCENTAGE_BASE_KEYS = %i[first_second_fare additional_fare single_supplement].freeze

  OCCUPANCY_PROFILE_SPECS = {
    single: { label: "Single occupancy", positions: 1 },
    double: { label: "Double occupancy", positions: 2 },
    triple: { label: "Triple occupancy", positions: 3 }
  }.freeze

  module_function

  def canonical_labels
    CANONICAL_SPECS.values.map { |spec| spec.fetch(:label) } + [ COMMISSION_LABEL ]
  end

  def term_key_for_label(label)
    CANONICAL_SPECS.each do |key, spec|
      return key if spec.fetch(:label) == label
    end
    return :commission if label == COMMISSION_LABEL

    nil
  end

  def occupancy_keys_for_maximum(maximum_occupancy)
    max = maximum_occupancy.to_i
    keys = []
    keys << :single if max >= 1
    keys << :double if max >= 2
    keys << :triple if max >= 3
    keys
  end
end
