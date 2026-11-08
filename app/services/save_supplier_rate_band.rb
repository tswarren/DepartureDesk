# Adds a band to a custom rate pattern (S-14): its label, its positions and
# the traveler type it is for, if any, such as a child fare in the 3rd and
# 4th berths. Overlapping bands for the same travelers are refused.
class SaveSupplierRateBand < AgencyCommand
  include SupplierRateCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, attributes:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @attributes = attributes.to_h.stringify_keys
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      arrangement = lock_draft_arrangement!
      positions = Array(@attributes["positions"]).compact_blank & SupplierRateLine::OCCUPANCY_POSITIONS
      raise Error.new("Positions: choose at least one.", code: :invalid) if positions.empty?

      type_id = @attributes["traveler_type_id"].presence
      type = type_id && (@agency.traveler_types.find_by(id: parse_optional_uuid(type_id, "Traveler type")) || raise(Error.new("Choose one of the agency's traveler types.", code: :invalid)))
      ensure_no_overlap!(arrangement, positions, type&.id)
      label = @attributes["label"].presence || default_label(positions, type)
      band = arrangement.rate_bands.create!(agency: @agency, label:, positions: SupplierRateLine::OCCUPANCY_POSITIONS & positions,
        traveler_type: type, position: arrangement.rate_bands.maximum(:position).to_i + 1)
      arrangement.update!(rate_pattern: "custom")
      audit!(agency: @agency, action: "supplier_arrangement.rate_band_added", subject: arrangement, actor: @actor,
        details: { "supplier_rate_band_id" => band.id, "label" => band.label, "positions" => band.positions, "traveler_type_id" => band.traveler_type_id })
      Result.new(status: :created, record: band)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def default_label(positions, type)
    names = positions.map { |position| position == "single" ? "single" : position.delete_prefix("guest_").to_i.ordinalize }
    [ type&.name, names.to_sentence ].compact.join(", ")
  end
end
