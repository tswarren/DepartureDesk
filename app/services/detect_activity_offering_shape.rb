# frozen_string_literal: true

class DetectActivityOfferingShape
  Offering = Data.define(:item, :item_definition, :occurrence_definition, :template)

  Result = Data.define(:compatible, :empty, :advanced, :reasons, :version, :offerings) do
    def compatible? = compatible
    def empty? = empty
    def advanced? = advanced
  end

  CATEGORIES = %w[activity_attraction dining].freeze

  def initialize(agency:, arrangement:)
    @agency = agency
    @arrangement = arrangement
  end

  def call
    version = @arrangement.versions.find_by(status: "draft") || @arrangement.governing_version || @arrangement.versions.order(:version_number).last
    definitions = version&.arrangement_item_definitions&.where(category: CATEGORIES)&.order(:position, :id)&.to_a || []
    return Result.new(compatible: false, empty: true, advanced: false, reasons: [], version: version, offerings: []) if definitions.empty?

    offerings = definitions.map do |definition|
      occurrence = version.service_occurrence_definitions.find_by(arrangement_item_id: definition.arrangement_item_id)
      Offering.new(
        item: definition.arrangement_item, item_definition: definition, occurrence_definition: occurrence,
        template: definition.category == "dining" ? "meal" : "activity"
      )
    end
    Result.new(compatible: true, empty: false, advanced: false, reasons: [], version: version, offerings: offerings)
  end
end
