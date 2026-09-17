module M3CCostScenarioHelper
  CELEBRITY_O1_AMOUNTS = {
    first_second_fare: 162_400,
    additional_fare: 40_600,
    nccf: 32_000,
    first_second_discount: 15_000,
    additional_discount: 3_750,
    taxes_fees_port_charges: 13_700
  }.freeze

  CELEBRITY_O1_ANONYMOUS_PROFILES = [
    { label: "Single occupancy", resource_unit_count: 1, occupancy_positions: [ 1 ] },
    { label: "Double occupancy", resource_unit_count: 1, occupancy_positions: [ 1, 2 ] },
    { label: "Triple occupancy", resource_unit_count: 1, occupancy_positions: [ 1, 2, 3 ] }
  ].freeze
end
