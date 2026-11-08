module BookingsHelper
  STATUS_MODIFIERS = { "draft" => "neutral", "confirmed" => "success", "discarded" => "neutral", "cancelled" => "danger" }.freeze

  # A link to a workspace section: on this step, its anchor; else its step.
  def booking_section_path(booking, anchor)
    BookingProgress.step_for(anchor) == @step ? "##{anchor}" : booking_step_path(booking, anchor)
  end

  def booking_status_badge(booking)
    status_badge(booking.status_label, modifier: STATUS_MODIFIERS.fetch(booking.status))
  end

  # Held until, or Hold expired with its time (BKG-09, D-80), as text and color.
  def booking_hold_badge(booking)
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
end
