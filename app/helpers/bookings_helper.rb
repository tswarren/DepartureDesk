module BookingsHelper
  STATUS_MODIFIERS = { "draft" => "neutral", "confirmed" => "success", "discarded" => "neutral", "cancelled" => "danger" }.freeze

  # A link to a workspace section: on this step, its anchor; else its step.
  def booking_section_path(booking, anchor)
    BookingProgress.step_for(anchor) == @step ? "##{anchor}" : booking_step_path(booking, anchor)
  end

  DefaultOccupants = Data.define(:ids, :note)

  # Who a new unit or add-on starts with. A unit in another per-unit choice
  # follows the matching unit of the first one, so rooms follow the cabin;
  # each extra night follows the first cabin. Otherwise the travelers not
  # yet in the choice, for an included choice; none for an add-on.
  def default_occupants(booking, choice, choices)
    return DefaultOccupants.new(ids: [], note: nil) if choice.made_per_trip?

    placed = booking.choice_selections.select { |selection| selection.choice.id == choice.id }
    leader = choices.find(&:made_per_unit?)
    if choice.made_per_unit? && leader && leader.id != choice.id
      units = booking.choice_selections.select { |selection| selection.choice.id == leader.id }.sort_by(&:unit_number)
      unit = units[choice.optional_multiple? ? 0 : placed.size]
      return DefaultOccupants.new(ids: unit.occupants.map(&:booking_traveler_id), note: "The same travelers as #{unit.label}.") if unit
    end
    return DefaultOccupants.new(ids: [], note: nil) unless choice.included?

    taken = placed.flat_map { |selection| selection.occupants.map(&:booking_traveler_id) }
    DefaultOccupants.new(ids: booking.booking_travelers.map(&:id) - taken, note: nil)
  end

  SupplierStatus = Data.define(:label, :detail, :modifier, :needs_request)

  # A service's supplier status, apart from its allocation state (INV-34,
  # INV-37): a reservation's status, Awaiting supplier while Requested on a
  # confirmed booking, guidance when a request is still needed, or the
  # group block. Guidance has no modifier and is shown as text, not a
  # status badge. Nil when the arrangement tracks no reservations.
  def supplier_status(selection, booking)
    reservation = selection.open_supplier_reservation
    if reservation&.status_confirmed?
      SupplierStatus.new(label: "Confirmed by the supplier", detail: "Ref #{reservation.supplier_reference}", modifier: "success", needs_request: false)
    elsif reservation
      label = booking.status_confirmed? ? "Awaiting supplier" : "Requested"
      SupplierStatus.new(label:, detail: "Requested #{reservation.requested_at.in_time_zone(Current.agency.default_timezone).to_fs(:long)}", modifier: "warning", needs_request: false)
    elsif selection.needs_supplier_request?
      SupplierStatus.new(label: "Request from the supplier", detail: nil, modifier: nil, needs_request: true)
    elsif !selection.inventory_group.supplier_arrangement.reservations_none?
      SupplierStatus.new(label: "In the group block", detail: nil, modifier: nil, needs_request: false)
    end
  end

  # The roster's supplier column: services awaiting the supplier, then
  # those still to request, else a dash (INV-37).
  def booking_supplier_summary(booking)
    statuses = booking.choice_selections.filter_map { |selection| supplier_status(selection, booking) }
    awaiting = statuses.count { |status| status.label.in?([ "Awaiting supplier", "Requested" ]) }
    to_request = statuses.count(&:needs_request)
    parts = []
    parts << status_badge("#{awaiting} #{booking.status_confirmed? ? "awaiting supplier" : "requested"}", modifier: "warning") if awaiting.positive?
    parts << "#{to_request} to request" if to_request.positive?
    parts.any? ? safe_join(parts, " ") : "—"
  end

  def booking_status_badge(booking)
    status_badge(booking.status_label, modifier: STATUS_MODIFIERS.fetch(booking.status))
  end

  # Space reserved once confirmed, else Held until or Hold expired with its
  # time (BKG-09, D-80), as text and color.
  def booking_hold_badge(booking)
    return status_badge("Space reserved", modifier: "info") if booking.inventory_allocations.any?(&:state_reserved?)

    state, at = booking.hold_state
    case state
    when :held then status_badge("Held until #{booking_time(at)}", modifier: "info")
    when :expired then status_badge("Hold expired #{booking_time(at)}", modifier: "warning")
    else tag.span("No hold", class: "dd-cell-subtext")
    end
  end

  def booking_time(time)
    time.in_time_zone(Current.agency.default_timezone).strftime("%b %-d, %Y, %-l:%M %p").sub("AM", "a.m.").sub("PM", "p.m.")
  end

  # CMN-19, CMN-52: every staff user sees client money, and so does the
  # reseller that owns the booking.
  def booking_client_money_visible?
    reseller_area? ? Current.agency_user.permitted?(:reseller_view_offers) : Current.agency_user.permitted?(:view_client_money)
  end

  def booking_money(minor_units, currency)
    Money.new(minor_units, currency).format
  end

  # INV-39: the group's rule says this traveler's type uses no capacity.
  def uses_no_capacity?(group, booking_traveler)
    group.capacity_rules.any? { |rule| rule.traveler_type_id == booking_traveler.traveler_type_id && !rule.uses_capacity? }
  end

  def allocation_state_label(allocation)
    return "Hold expired" if allocation.lapsed?

    allocation.state.titleize
  end

  # The booking's units of its first included per-unit choice, such as its cabins.
  def booking_cabins(booking)
    choice = booking.offering.choices.find { |candidate| candidate.included? && candidate.made_per_unit? }
    labels = booking.choice_selections.select { |selection| choice && selection.option.offering_choice_id == choice.id }.map { |selection| selection.option.label }
    labels.join(", ").presence || "None chosen"
  end

  # The booking's services in package order, each with its price lines (S-26 Summary).
  def booking_services(booking)
    booking.choice_selections.sort_by { |selection| [ selection.option.choice.position, selection.option.position, selection.unit_number.to_i ] }
  end

  # Where one traveler is placed on each service, in words (S-26 Summary).
  def booking_traveler_placements(booking, booking_traveler)
    booking_services(booking).filter_map do |selection|
      occupant = selection.occupants.find { |row| row.booking_traveler_id == booking_traveler.id }
      next unless occupant

      if selection.per_unit? && occupant.position
        "#{selection.label}, #{occupant.position.ordinalize} guest"
      elsif uses_no_capacity?(selection.inventory_group, booking_traveler)
        "#{selection.label}, without a position"
      else
        selection.label
      end
    end
  end

  # A service's space in words: each allocation's state, or Not held.
  def booking_service_space(selection)
    allocations = selection.inventory_allocations.reject(&:state_released?)
    return "Not held" if allocations.empty?

    allocations.map(&:state).uniq.size == 1 ? allocation_state_label(allocations.first) : allocations.map { |allocation| allocation_state_label(allocation) }.tally.map { |label, count| "#{count} #{label.downcase}" }.join(", ")
  end

  # Each payment applied to this charge, with what went to each installment (CMN-28).
  def booking_payments_applied(charge)
    charge.installments.flat_map { |installment| installment.applications.map { |application| [ application, installment ] } }
      .group_by { |application, _| application.client_payment }
      .filter_map do |payment, rows|
        amounts = rows.group_by(&:last).transform_values { |pairs| pairs.sum { |application, _| application.amount_minor_units } }.select { |_, amount| amount.positive? }
        [ payment, amounts ] if amounts.any?
      end
      .sort_by { |payment, _| [ payment.paid_on, payment.payment_reference ] }
  end
end
