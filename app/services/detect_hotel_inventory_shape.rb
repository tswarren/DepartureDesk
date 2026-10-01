# frozen_string_literal: true

class DetectHotelInventoryShape
  ItemShape = Data.define(
    :item,
    :item_definition,
    :stay_definition,
    :candidate_dates,
    :categories,
    :nights,
    :resources,
    :cells,
    :reasons,
    :room_night_count,
    :category_count
  ) do
    def supported?
      reasons.empty?
    end

    def blocked?
      !supported?
    end
  end

  CategoryShape = Data.define(:resource_definition, :cells, :reason, :room_night_count) do
    def supported?
      reason.nil?
    end
  end

  Cell = Data.define(:date, :night_definition, :resource_definition, :pool_definition, :reason) do
    def supported?
      reason.nil?
    end
  end

  def self.lodging_items(version)
    version.arrangement_item_definitions
      .select { |definition| definition.category == "lodging" }
      .sort_by { |definition| [ definition.position || 0, definition.arrangement_item_id ] }
      .map(&:arrangement_item)
  end

  def initialize(agency:, arrangement:, version:, item:)
    @agency = agency
    @arrangement = arrangement
    @version = version
    @item = item
  end

  def call
    definition = item_definitions.find { |row| row.arrangement_item_id == @item.id }
    return empty_shape(nil, [ "This Item is not on the editable Arrangement Version." ]) if definition.nil?

    reasons = []
    reasons << "Hotel inventory requires a lodging Item." unless definition.category == "lodging"
    reasons << "Hotel inventory requires a capacity-managed Item." unless definition.capacity_management == "managed"

    occurrences = occurrence_definitions.select { |row| row.arrangement_item_id == @item.id }
      .sort_by { |row| [ row.starts_on, row.id ] }
    stay = select_stay(occurrences, reasons)
    dates = candidate_dates(stay)
    nights_by_date = recognized_nights(occurrences, stay, dates, reasons)
    reasons << "The Stay has a Capacity Pool." if stay && pools_for(stay).any?

    resources = resource_definitions
    categories = resources.map { |resource| category_shape(stay, resource, dates, nights_by_date) }
    cells = categories.flat_map(&:cells)
    nights = nights_by_date.values.flatten

    ItemShape.new(
      item: @item,
      item_definition: definition,
      stay_definition: stay,
      candidate_dates: dates,
      categories: categories,
      nights: nights,
      resources: resources,
      cells: cells,
      reasons: reasons.uniq,
      room_night_count: cells.sum { |cell| countable_quantity(cell) },
      category_count: resources.size
    )
  end

  private

  def empty_shape(definition, reasons)
    ItemShape.new(
      item: @item,
      item_definition: definition,
      stay_definition: nil,
      candidate_dates: [],
      categories: [],
      nights: [],
      resources: [],
      cells: [],
      reasons: reasons,
      room_night_count: 0,
      category_count: 0
    )
  end

  def item_definitions
    @item_definitions ||= association_records(@version, :arrangement_item_definitions) do
      @version.arrangement_item_definitions.includes(:arrangement_item).to_a
    end
  end

  def occurrence_definitions
    @occurrence_definitions ||= association_records(@version, :service_occurrence_definitions) do
      @version.service_occurrence_definitions.includes(:service_occurrence).to_a
    end
  end

  def resource_definitions
    @resource_definitions ||= association_records(@version, :supplier_resource_definitions) do
      @version.supplier_resource_definitions.includes(:supplier_resource).to_a
    end.select { |row| row.arrangement_item_id == @item.id }
      .sort_by { |row| [ row.position || 0, row.id ] }
  end

  def pool_definitions
    @pool_definitions ||= association_records(@version, :capacity_pool_definitions) do
      @version.capacity_pool_definitions.includes(:capacity_pool).to_a
    end
  end

  def pair_definitions
    @pair_definitions ||= association_records(@version, :capacity_pair_definitions) do
      @version.capacity_pair_definitions.to_a
    end
  end

  def association_records(version, name)
    association = version.association(name)
    return association.target if association.loaded?

    yield
  end

  def select_stay(occurrences, reasons)
    stays = occurrences.select { |occurrence| occurrence.starts_on != occurrence.ends_on }
    reasons << "Hotel setup requires one Stay." unless stays.one?
    reasons << "An extra Service Occurrence cannot be edited here." if stays.size > 1
    stays.one? ? stays.first : nil
  end

  def candidate_dates(stay)
    return [] if stay.nil?

    (stay.starts_on...stay.ends_on).to_a
  end

  def recognized_nights(occurrences, stay, dates, reasons)
    grouped = Hash.new { |hash, key| hash[key] = [] }
    extras = []
    occurrences.each do |occurrence|
      next if stay && occurrence.id == stay.id

      if occurrence.starts_on == occurrence.ends_on && dates.include?(occurrence.starts_on)
        grouped[occurrence.starts_on] << occurrence
      else
        extras << occurrence
      end
    end
    reasons << "An extra Service Occurrence cannot be edited here." if extras.any? || grouped.values.any? { |rows| rows.many? }
    grouped
  end

  def category_shape(stay, resource, dates, nights_by_date)
    cells = dates.map do |date|
      nights = nights_by_date[date]
      night = nights.one? ? nights.first : nil
      Cell.new(
        date: date,
        night_definition: night,
        resource_definition: resource,
        pool_definition: night ? sole_pool(night, resource) : nil,
        reason: nights.many? ? "An extra Service Occurrence cannot be edited here." : cell_reason(night, resource)
      )
    end
    CategoryShape.new(
      resource_definition: resource,
      cells: cells,
      reason: stay_category_reason(stay, resource),
      room_night_count: cells.sum { |cell| countable_quantity(cell) }
    )
  end

  def stay_category_reason(stay, resource)
    return "Hotel setup requires one Stay." if stay.nil?

    pair = pair_for(stay, resource)
    return "The Stay has no room-category classification." if pair.nil?
    return "The Stay is classified for a room category." unless pair.classification == "not_applicable"
    return "The Stay has a Capacity Pool." if pools_for(stay).any? { |pool| pool.supplier_resource_id == resource.supplier_resource_id }

    nil
  end

  def cell_reason(night, resource)
    return nil if night.nil?
    return "A room night has a local time." if local_time?(night)

    pair = pair_for(night, resource)
    pools = pools_for(night).select { |pool| pool.supplier_resource_id == resource.supplier_resource_id }
    return nil if pools.empty? && (pair.nil? || pair.classification == "pooled")
    return "A room night Pool is not one numeric block measured in rooms." unless pools.one? && pair&.classification == "pooled" && numeric_room_block?(pools.first)

    nil
  end

  def local_time?(occurrence)
    occurrence.starts_at_local.present? || occurrence.ends_at_local.present?
  end

  def numeric_room_block?(definition)
    pool = definition.capacity_pool
    definition.proposed_opening_quantity.is_a?(Integer) &&
      definition.unit_label.to_s.casecmp("rooms").zero? &&
      pool&.block? &&
      pool.resource_units?
  end

  def countable_quantity(cell)
    return 0 unless cell.supported? && cell.pool_definition

    cell.pool_definition.proposed_opening_quantity.to_i
  end

  def sole_pool(night, resource)
    pools = pools_for(night).select { |pool| pool.supplier_resource_id == resource.supplier_resource_id }
    pools.one? ? pools.first : nil
  end

  def pools_for(occurrence)
    pool_definitions.select { |pool| pool.service_occurrence_id == occurrence.service_occurrence_id }
  end

  def pair_for(occurrence, resource)
    pair_definitions.find do |pair|
      pair.service_occurrence_id == occurrence.service_occurrence_id &&
        pair.supplier_resource_id == resource.supplier_resource_id
    end
  end
end
