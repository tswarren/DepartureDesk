# frozen_string_literal: true

# Presentation facts for the Cabin inventory workspace. Quantity, opening,
# carried, and rate posture come from CompileCruiseCompositionSummary.
# Attention is the existing opening-authority finding only.
class CompileCruiseCabinInventoryWorkspace
  AttentionItem = Data.define(:code, :message, :resource_id)
  Result = Data.define(
    :advanced?, :category_count, :tracked_cabin_count, :untracked_category_count,
    :quantity_meaning, :carried_count, :proposed_count, :successor, :rows, :attention_items
  )

  def initialize(agency:, arrangement:, shape:, rows: nil, readiness: nil)
    @agency = agency
    @arrangement = arrangement
    @shape = shape
    @rows = rows
    @readiness = readiness
  end

  def call
    return empty_result(advanced: true) unless @shape.compatible?

    version = @shape.version
    rows = @rows || CompileCruiseCompositionSummary.new(
      agency: @agency,
      arrangement: @arrangement,
      shape: @shape
    ).cabin_inventory_rows
    return empty_result(advanced: true) if rows.any? { |row| row.inventory_label == "Inventory not configured" }

    successor = version&.draft? && version.copied_from_id.present?
    carried_count = rows.count(&:carried)
    proposed_count = if successor
      rows.count { |row| !row.carried && tracked_quantity?(row) }
    else
      0
    end
    tracked = tracked_cabin_count(rows)
    meaning = if tracked.nil?
      nil
    elsif version&.activated?
      :active_capacity
    else
      :proposed
    end

    Result.new(
      advanced?: false,
      category_count: rows.size,
      tracked_cabin_count: tracked,
      untracked_category_count: untracked_category_count(rows),
      quantity_meaning: meaning,
      carried_count: carried_count,
      proposed_count: proposed_count,
      successor: successor,
      rows: rows,
      attention_items: attention_items(version)
    )
  end

  private

  def empty_result(advanced:)
    Result.new(
      advanced?: advanced,
      category_count: 0,
      tracked_cabin_count: nil,
      untracked_category_count: 0,
      quantity_meaning: nil,
      carried_count: 0,
      proposed_count: 0,
      successor: false,
      rows: [],
      attention_items: []
    )
  end

  def tracked_cabin_count(rows)
    return nil if rows.any?(&:carried)

    numeric = rows.select { |row| tracked_quantity?(row) }
    return nil if numeric.empty?
    return nil if numeric.any? { |row| row.quantity.nil? }

    numeric.sum { |row| row.quantity.to_i }
  end

  def untracked_category_count(rows)
    rows.count { |row| row.quantity_label == "Quantity not tracked" }
  end

  def tracked_quantity?(row)
    row.quantity_label != "Quantity not tracked" && row.inventory_label != "Inventory not configured"
  end

  def attention_items(version)
    return [] if version.nil?

    review = CompileCruiseActivationReview.new(
      agency: @agency,
      arrangement: @arrangement,
      version: version,
      presentation: false,
      readiness: supplied_readiness(version)
    ).call
    review.blockers.filter_map do |blocker|
      next unless blocker.code == :opening_authority_incomplete
      next if version.capacity_pool_definitions.includes(:capacity_pool).any? { |definition|
        definition.supplier_resource_id == blocker.resource_id &&
          definition.capacity_pool.numeric_inventory? &&
          definition.proposed_opening_quantity.to_i.positive?
      }

      AttentionItem.new(code: blocker.code, message: blocker.message, resource_id: blocker.resource_id)
    end
  end

  def supplied_readiness(version)
    readiness = @readiness
    return nil if readiness.nil? || readiness.version&.id != version&.id

    readiness
  end
end
