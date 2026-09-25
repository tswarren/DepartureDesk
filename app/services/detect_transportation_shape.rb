# frozen_string_literal: true

class DetectTransportationShape
  Segment = Data.define(:item, :item_definition, :occurrence_definition, :advanced, :reasons)

  Result = Data.define(:compatible, :empty, :advanced, :reasons, :version, :segments) do
    def compatible? = compatible
    def empty? = empty
    def advanced? = advanced
  end

  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    version = @arrangement.versions.find_by(status: "draft") || @arrangement.governing_version || @arrangement.versions.order(:version_number).last
    definitions = version&.arrangement_item_definitions&.where(category: "ground_transportation")&.order(:position, :id)&.to_a || []
    return Result.new(compatible: false, empty: true, advanced: false, reasons: [], version: version, segments: []) if definitions.empty?

    segments = definitions.map { |definition| segment_for(version, definition) }
    reasons = segments.flat_map(&:reasons)
    Result.new(
      compatible: reasons.empty?, empty: false, advanced: reasons.any?, reasons: reasons,
      version: version, segments: segments
    )
  end

  private

  def segment_for(version, definition)
    occurrences = version.service_occurrence_definitions.where(arrangement_item_id: definition.arrangement_item_id).to_a
    reasons = occurrences.one? ? [] : [ "#{definition.name} needs one schedule." ]
    Segment.new(
      item: definition.arrangement_item, item_definition: definition,
      occurrence_definition: occurrences.first, advanced: reasons.any?, reasons: reasons
    )
  end
end
