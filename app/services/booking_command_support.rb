# Shared by the booking commands (BKG-05 to BKG-11, BKG-14 to BKG-16,
# BKG-23, BKG-45, CLT-13, CLT-15, INV-09, INV-17 to INV-23, INV-39, D-88;
# step 6 plan, questions 7, 8 and 14 to 21). Every staff user may book
# (ACC-30).
#
# Lock order (question 16): agency, Departure, booking, then each affected
# arrangement and each affected inventory group in id order. Supply
# commands take agency, Departure, arrangement, group, so both paths take
# the group row last and are ordered on one timeline per group.
module BookingCommandSupport
  Need = Data.define(:selection, :group, :kind, :count)

  private

  def ensure_actor!
    ensure_directory_actor!(@actor, @agency, :manage_bookings)
    ensure_active_agency!(@agency)
  end

  def lock_booking!(booking = @booking)
    @agency.lock!
    trip = @agency.client_trips.find(booking.client_trip_id)
    @departure = @agency.departures.lock.find(trip.departure_id)
    @agency.client_bookings.lock.find(booking.id)
  end

  def ensure_draft!(booking)
    raise AgencyCommand::Error.new("Only a draft booking can change here.", code: :invalid_state) unless booking.status_draft?
  end

  def ensure_version!(record)
    return if @lock_version.nil? || record.lock_version == @lock_version.to_i

    raise AgencyCommand::Error.new("This booking changed. Reload it and try again.", code: :conflict)
  end

  # DEP-05: new bookings, holds and confirmation need the Departure On sale.
  def ensure_on_sale!(departure, action)
    return if departure.on_sale?

    reason = if !departure.completion_active? then "it is #{departure.summary_label_text.downcase}"
    elsif departure.decision_cancel? || departure.decision_postpone? then "its operating decision is #{departure.operating_decision.humanize.downcase}"
    else "it is not Ready to sell"
    end
    raise AgencyCommand::Error.new("#{departure.name} isn't on sale, so #{action}: #{reason}.", code: :invalid_state)
  end

  def lock_groups!(groups)
    groups = groups.uniq(&:id)
    SupplierArrangement.where(id: groups.map(&:supplier_arrangement_id).uniq).order(:id).lock.to_a
    InventoryGroup.where(id: groups.map(&:id)).order(:id).lock.includes(:capacity_events, :capacity_rules, :inventory_allocations, unit_shells: %i[capacity_events inventory_allocations]).to_a
  end

  def clean(attributes, fields)
    attributes.to_h.stringify_keys.slice(*fields).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
  end

  def audit_booking!(booking, action, details = {})
    audit!(agency: @agency, action:, subject: booking, actor: @actor,
      details: { "client_booking_id" => booking.id, "booking_reference" => booking.booking_reference }.merge(details))
  end

  # INV-39: a traveler whose type the group's rule marks as using no capacity.
  def uses_capacity?(group, booking_traveler)
    rule = group.capacity_rules.find { |candidate| candidate.traveler_type_id == booking_traveler.traveler_type_id }
    rule.nil? || rule.uses_capacity?
  end

  # Positions within a unit: occupants who use capacity get 1, 2, ... in the
  # booking's order; the others none (question 19, INV-39).
  def position_occupants!(selection, booking_travelers)
    group = selection.inventory_group
    selection.occupants.delete_all(:delete_all)
    position = 0
    booking_travelers.each do |traveler|
      counts = selection.per_unit? && uses_capacity?(group, traveler)
      selection.occupants.create!(agency: @agency, booking_traveler: traveler, position: (counts ? position += 1 : nil))
    end
  end

  # Question 14: price lines are proposed for contents that need one and
  # kept while those contents don't change. A change to an offering price
  # touches no line (BKG-23).
  def refresh_price_lines!(booking)
    booking.price_lines.reset
    wanted = desired_price_lines(booking)
    existing = booking.price_lines.to_a
    keep = existing.select { |line| wanted.key?(price_key(line)) }
    BookingPriceLine.where(id: (existing - keep).map(&:id)).delete_all
    kept_keys = keep.map { |line| price_key(line) }
    wanted.except(*kept_keys).each_value do |attributes|
      price = attributes.delete(:price)
      next if price.nil?

      booking.price_lines.create!(agency: @agency, offering_price: price, amount_minor_units: price.amount_minor_units, currency: price.currency, **attributes)
    end
    booking.price_lines.reset
  end

  def price_key(line)
    [ line.choice_selection_id, line.booking_traveler_id, line.occupancy_position, line.traveler_type_id ]
  end

  def desired_price_lines(booking)
    booking.choice_selections.reload.includes(:occupants, option: [ :prices, :choice ]).each_with_object({}) do |selection, wanted|
      lookup = OfferingPriceLookup.new(option: selection.option)
      if selection.choice.made_per_trip?
        key = [ selection.id, nil, "any", nil ]
        wanted[key] = { choice_selection: selection, booking_traveler: nil, occupancy_position: "any", traveler_type: nil, price: lookup.price_for(occupancy_position: "any") }
        next
      end
      counted = selection.occupants.count(&:position)
      selection.occupants.each do |occupant|
        traveler = booking.booking_travelers.find { |candidate| candidate.id == occupant.booking_traveler_id }
        position = if selection.per_unit? && occupant.position
          counted == 1 ? "single" : "guest_#{occupant.position}"
        else
          "any"
        end
        key = [ selection.id, traveler.id, position, traveler.traveler_type_id ]
        wanted[key] = { choice_selection: selection, booking_traveler: traveler, occupancy_position: position,
                        traveler_type: traveler.traveler_type, price: lookup.price_for(occupancy_position: position, traveler_type: traveler.traveler_type) }
      end
    end
  end

  # What a hold takes for each selection drawn from numeric inventory
  # (question 8). On-request and rate-only groups take nothing (BKG-11).
  def allocation_needs(booking)
    booking.choice_selections.includes(:occupants, option: [ :choice, { inventory_group: :capacity_rules } ]).filter_map do |selection|
      group = selection.inventory_group
      next unless group.numeric?

      if selection.per_traveler?
        count = selection.occupants.count { |occupant| uses_capacity?(group, booking.booking_travelers.find { |bt| bt.id == occupant.booking_traveler_id }) }
        next if count.zero?

        Need.new(selection:, group:, kind: group.represented_as_unit_shells? ? :positions : :places, count:)
      else
        Need.new(selection:, group:, kind: group.represented_as_unit_shells? ? :whole_shell : :places, count: 1)
      end
    end
  end

  def allocation_count(allocation)
    allocation.unit_shell && allocation.choice_selection.per_unit? ? 1 : allocation.quantity
  end

  def need_signature(need) = [ need.selection.id, need.group.id, need.count ]

  def allocation_signature(allocation) = [ allocation.choice_selection_id, allocation.inventory_group_id, allocation_count(allocation) ]

  # INV-09: each unit's occupants against the group's maximum occupancy and
  # required adults (question 21).
  def occupancy_problems(booking)
    booking.choice_selections.select(&:per_unit?).flat_map do |selection|
      group = selection.inventory_group
      counted = selection.occupants.count(&:position)
      problems = []
      problems << "#{selection.label} has no travelers in it." if selection.occupants.empty?
      if group.positions_per_unit && counted > group.positions_per_unit
        problems << "#{selection.label} has #{counted} travelers using positions; it holds #{group.positions_per_unit}."
      end
      if group.required_adults_per_unit
        adults = selection.occupants.count { |occupant| booking.booking_travelers.find { |bt| bt.id == occupant.booking_traveler_id }&.counts_as_adult? }
        if adults < group.required_adults_per_unit
          problems << "#{selection.label} needs #{group.required_adults_per_unit} #{"adult".pluralize(group.required_adults_per_unit)}; it has #{adults}."
        end
      end
      problems
    end
  end

  # Allocates the needs, all or none (BKG-11). Raises naming every service
  # that can't be held. Replacements keep the expiry and extension of what
  # they replace (questions 15 and 20).
  def allocate!(booking, needs, expires_at:, extended_at: nil, replacing: {}, shell_choices: {})
    groups = lock_groups!(needs.map(&:group))
    capacities = groups.to_h { |group| [ group.id, GroupCapacity.new(group:) ] }
    taken_shells = []
    taken_positions = Hash.new(0)
    failures = []
    excluding = replacing.values.flatten.map(&:id)
    plans = needs.filter_map do |need|
      group = groups.find { |candidate| candidate.id == need.group.id }
      capacity = capacities.fetch(group.id)
      unless group.supplier_arrangement.confirmed?
        failures << "#{need.selection.label}: #{group.label} isn't confirmed with the supplier yet."
        next
      end
      if capacity.conflict?
        failures << "#{need.selection.label}: the supplier reduced #{group.label} below what is held; resolve it before holding."
        next
      end
      plan = case need.kind
      when :whole_shell
        free = capacity.free_shells(excluding:).reject { |shell| taken_shells.include?(shell.id) }
        chosen = free.find { |shell| shell.id == shell_choices[need.selection.id] } ||
          free.find { |shell| replacing[need.selection.id]&.any? { |allocation| allocation.unit_shell_id == shell.id } } || free.first
        chosen && { shell: chosen, quantity: chosen.positions }
      when :positions
        shell = capacity.shell_with_positions(need.count + taken_positions[group.id], excluding:)
        shell && { shell:, quantity: need.count }
      when :places
        { shell: nil, quantity: need.count }
      end
      if plan.nil?
        failures << "#{need.selection.label}: no #{group.label} space is left."
        next
      end
      case need.kind
      when :whole_shell then taken_shells << plan[:shell].id
      when :positions then taken_positions[group.id] += need.count
      end
      [ need, plan ]
    end
    # D-88, INV-23: the group's supply must cover the new holds at every
    # point until they expire, counting changes already scheduled.
    plans.group_by { |need, _| need.group.id }.each do |group_id, group_plans|
      capacity = capacities.fetch(group_id)
      added = group_plans.map do |_, plan|
        GroupCapacity::Projected.new(id: nil, unit_shell_id: plan[:shell]&.id, quantity: plan[:quantity], state: "held", hold_expires_at: expires_at)
      end
      next unless capacity.shortfall(capacity.project(removed: excluding, added:))

      label = group_plans.first.first.group.label
      failures << "#{group_plans.map { |need, _| need.selection.label }.join(", ")}: no #{label} space is left for the length of the hold, counting supply changes already scheduled."
    end
    raise AgencyCommand::Error.new("Space can't be held: #{failures.join(" ")}", code: :invalid) if failures.any?

    now = Clock.current.now
    plans.map do |need, plan|
      replaced = replacing[need.selection.id]
      replaced&.each { |allocation| allocation.update!(state: "released", released_at: now) }
      booking.inventory_allocations.create!(
        agency: @agency, choice_selection: need.selection, inventory_group: need.group, unit_shell: plan[:shell], quantity: plan[:quantity],
        state: "held", held_at: now, hold_expires_at: expires_at, hold_extended_at: extended_at,
        replaces: replaced&.first, created_by: @actor
      )
    end
  end

  def hold_expiry(departure)
    today = Clock.current.today_in(@agency.default_timezone)
    AgencyLocalTime.end_of_date(today + (departure.effective_hold_duration_days - 1), @agency.default_timezone)
  end

  # Question 15: after an edit to a booking with active holds, re-hold what
  # changed in the same transaction, or refuse the edit whole.
  def sync_holds!(booking)
    booking.inventory_allocations.reset
    active = booking.consuming_allocations.select(&:state_held?)
    return if active.empty?

    needs = allocation_needs(booking)
    wanted = needs.map { |need| need_signature(need) }
    stale = active.reject { |allocation| wanted.include?(allocation_signature(allocation)) }
    held = active.map { |allocation| allocation_signature(allocation) }
    missing = needs.reject { |need| held.include?(need_signature(need)) }
    return if stale.empty? && missing.empty?

    lock_groups!(stale.map(&:inventory_group) + missing.map(&:group))
    replacing = stale.group_by(&:choice_selection_id).slice(*missing.map { |need| need.selection.id })
    now = Clock.current.now
    (stale - replacing.values.flatten).each { |allocation| allocation.update!(state: "released", released_at: now) }
    return if missing.empty?

    allocate!(booking, missing, expires_at: active.map(&:hold_expires_at).min, extended_at: active.filter_map(&:hold_extended_at).min, replacing:)
  end

  # SUP-35: a unit's supplier cost and commission from its group's rate
  # table, for its occupants who use positions, in guest order.
  def supplier_proposal(booking, selection)
    guests = selection.occupants.select(&:position).sort_by(&:position).map do |occupant|
      booking.booking_travelers.find { |row| row.id == occupant.booking_traveler_id }&.traveler_type
    end
    ProposeBookingSupplierCost.new(group: selection.inventory_group, guests:).call
  end

  # Re-proposes prices and re-holds after a change to travelers or selections.
  def after_contents_change!(booking)
    refresh_price_lines!(booking)
    sync_holds!(booking)
  end
end
