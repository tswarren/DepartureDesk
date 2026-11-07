# What a group can still allocate, from its dated supply and the
# allocations consuming it (INV-23, INV-26, D-88). Supply is replayed from
# capacity events by the instant they apply. An allocation consumes while
# Reserved, or while Held until its expiry.
#
# Pools are counted in places, shell groups in shells: a shell counts once
# however many of its positions are taken. Every allocation must fit the
# supply at every point from now on, not only current supply, so a shell
# added with a later effective date can't be held before then, and a hold
# can't be confirmed or extended past a scheduled reduction. A supplier
# release recorded below what is allocated leaves a capacity conflict,
# which blocks new holds and confirmation until it is resolved (INV-19;
# step 6 plan, questions 17 and 20).
class GroupCapacity
  Point = Data.define(:at, :supply)

  # An allocation as it would be after a change that isn't saved yet: a new
  # hold, a hold confirmed as Reserved, or a hold with a later expiry.
  Projected = Data.define(:id, :unit_shell_id, :quantity, :state, :hold_expires_at) do
    def self.from(allocation, **changes)
      new(id: allocation.id, unit_shell_id: allocation.unit_shell_id, quantity: allocation.quantity,
        state: allocation.state, hold_expires_at: allocation.hold_expires_at).with(**changes)
    end

    def consuming?(at:) = state == "reserved" || (state == "held" && hold_expires_at > at)
  end

  def initialize(group:, at: Clock.current.now, events: nil, allocations: nil)
    @group = group
    @at = at
    @events = events || group.capacity_events.to_a
    @allocations = allocations || group.inventory_allocations.reject(&:state_released?)
  end

  # Supply now, then after each later event.
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

  # Units consumed at an instant: places for a pool, distinct shells for a shell group.
  def consumed(at = @at, allocations = @allocations)
    live = allocations.select { |allocation| allocation.consuming?(at:) }
    shells? ? live.map(&:unit_shell_id).uniq.size : live.sum(&:quantity)
  end

  # The largest shortfall at any point from `from` on, or nil when the
  # allocations fit. Pass projected allocations to test a change first.
  def shortfall(allocations = @allocations, from: @at)
    points.reject { |point| point.at < from }.filter_map do |point|
      short = consumed(point.at, allocations) - point.supply
      short if short.positive?
    end.max
  end

  # The group's allocations with these replaced, removed or added.
  def project(changed: [], removed: [], added: [])
    by_id = changed.index_by(&:id)
    kept = @allocations.reject { |allocation| removed.include?(allocation.id) }.map { |allocation| by_id[allocation.id] || allocation }
    kept + added
  end

  # Places a new pool allocation may take, at the lowest point from now on.
  def available_places(excluding: [])
    remaining = @allocations.reject { |allocation| excluding.include?(allocation.id) }
    points.map { |point| point.supply - consumed(point.at, remaining) }.min.to_i
  end

  def conflict?
    returned = shells? && @group.unit_shells.any? { |shell| shell.returned_to_supplier? && consuming_on(shell).positive? }
    returned || shortfall.present?
  end

  # Shells, in order, free for a whole-unit allocation now. Whether the
  # group's supply can take one more shell is checked with shortfall.
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
    new(group:, at:, events: group.capacity_events.to_a + [ event ]).shortfall(from: event.applies_at)
  end

  private

  def shells? = @group.represented_as_unit_shells?
end
