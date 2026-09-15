module SupplierCategory
  CODES = %w[
    cruise_line
    lodging
    air
    ground_transportation
    tour_operator_dmc
    dining
    activity_attraction
    insurance
    other
  ].freeze

  LABELS = {
    "cruise_line" => "Cruise line",
    "lodging" => "Lodging",
    "air" => "Air",
    "ground_transportation" => "Ground transportation",
    "tour_operator_dmc" => "Tour operator / DMC",
    "dining" => "Dining",
    "activity_attraction" => "Activity / attraction",
    "insurance" => "Insurance",
    "other" => "Other"
  }.freeze

  def self.normalize_codes(codes)
    normalized = Array(codes).flatten.compact_blank.map { |code| code.to_s.strip }.uniq.sort
    invalid = normalized - CODES
    raise ArgumentError, "Unknown supplier category: #{invalid.to_sentence}" if invalid.any?

    normalized
  end
end
