# What a group can still allocate, from its dated supply and the
# allocations consuming it (INV-23, INV-26, D-88). Supply is replayed from
# capacity events by the instant they apply. An allocation consumes while
# Reserved, or while Held until its expiry.
#
# Pools are counted in places. Shells are taken whole for a per-unit
# choice, or by position for a per-traveler choice such as an excursion
# resource (INV-16). A new hold must fit every supply point from now on,
# not only current supply. A supplier release recorded below what is
# allocated leaves a capacity conflict, which blocks new holds and
# confirmation until it is resolved (INV-19; step 6 plan, question 17).
class GroupCapacity
  Point = Data.define(:at, :supply)

  def initialize(group:, at: Clock.current.now, events: nil, allocations: nil)
    @group = group
    @at = at
    @events = events || group.capacity_events.to_a
    @allocations = allocations || group.inventory_allocations.reject(&:state_released?)
  end

  # Pool supply now, then after each later event.
  def points
    @points ||= begin
      ordered = @events.sort_by { |event| [ event.applies_at, event.effective_sequence, event.recorded_at ] }
      now_supply = ordered.select { |event| event.applies_at <= @at }.sum(&:signed_quantity)
      running = now_supply
      [ Point.new(at: @at, supply: now_supply) ] + ordered.select { |event| event.applies_at > @at }.map do |event|
        running += event.signed_quantity
        Point.new(at: event.applies_at, supply: running)
      end
    end
  end

  def consuming(at = @at, excluding: [])
    @allocations.reject { |allocation| excluding.include?(allocation.id) }.select { |allocation| allocation.consuming?(at:) }.sum(&:quantity)
  end

  # Places a new pool allocation may take, at the lowest point from now on.
  def available_places(excluding: [])
    points.map { |point| point.supply - consuming(point.at, excluding:) }.min.to_i
  end

  def conflict?
    if @group.represented_as_unit_shells?
      @group.unit_shells.any? { |shell| shell.returned_to_supplier? && consuming_on(shell).positive? }
    else
      points.any? { |point| consuming(point.at) > point.supply }
    end
  end

  # The first shell, in order, free for a whole-unit allocation.
  def free_shells(excluding: [])
    @group.unit_shells.reject(&:returned_to_supplier?).select { |shell| consuming_on(shell, excluding:).zero? }
  end

  # The first shell with this many positions free.
  def shell_with_positions(count, excluding: [])
    @group.unit_shells.reject(&:returned_to_supplier?).find { |shell| shell.positions - consuming_on(shell, excluding:) >= count }
  end

  def consuming_on(shell, excluding: [])
    @allocations.select { |allocation| allocation.unit_shell_id == shell.id && !excluding.include?(allocation.id) && allocation.consuming?(at: @at) }.sum(&:quantity)
  end

  # INV-26: an agency-initiated reduction may use only unallocated capacity,
  # at the instant it applies and at every point after.
  def self.shortfall_after(group:, event:, at: Clock.current.now)
    capacity = new(group:, at:, events: group.capacity_events.to_a + [ event ])
    capacity.points.reject { |point| point.at < event.applies_at }.filter_map do |point|
      short = capacity.consuming(point.at) - point.supply
      short if short.positive?
    end.max
  end
end
