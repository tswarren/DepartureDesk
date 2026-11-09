# Proposes a booking's installments from its terms version's payment
# schedule (CMN-09, D-77; step 8 plan, question 1), in the schedule's order:
# a fixed amount per traveler, per unit of a service category, or per
# booking; a percentage of the total, rounded half up; and the balance,
# whatever remains. Lines are capped so the installments never exceed the
# total. A per-unit line counts the booking's units of that category, its
# per-unit selections, since a draft is proposed before anything is held.
class InstallmentSchedule
  Row = Data.define(:position, :description, :amount_minor_units, :currency, :due_kind, :due_on)

  def initialize(booking:, terms_version:, total_minor_units:)
    @booking = booking
    @terms = terms_version
    @total = total_minor_units
  end

  def rows
    return [] if @terms.nil? || @total.nil?

    remaining = @total
    lines = @terms.schedule_lines.sort_by { |line| [ line.position.to_i, line.created_at ] }
    fixed, balances = lines.partition { |line| !line.basis_balance? }
    amounts = fixed.to_h do |line|
      amount = [ amount_for(line), remaining ].min
      remaining -= amount
      [ line.id, amount ]
    end
    balances.each_with_index { |line, index| amounts[line.id] = index.zero? ? remaining : 0 }
    lines.each_with_index.map do |line, index|
      kind, date = due_for(line)
      Row.new(position: index + 1, description: line.description, amount_minor_units: amounts.fetch(line.id), currency: @booking.currency, due_kind: kind, due_on: date)
    end
  end

  # What the proposals depend on; when it changes they are proposed afresh.
  def basis
    lines = @terms ? @terms.schedule_lines.map { |line| line.attributes.slice(*%w[id basis service_category amount_minor_units percentage due_rule days_before_departure due_on position]) } : []
    Digest::SHA256.hexdigest([ @terms&.id, lines.sort_by { |line| line["id"] }, @total, @booking.booking_travelers.size, units.sort.to_h, departure_start ].to_json)
  end

  private

  def amount_for(line)
    case line.basis
    when "per_traveler" then line.amount_minor_units * @booking.booking_travelers.size
    when "per_unit" then line.amount_minor_units * units.fetch(line.service_category, 0)
    when "per_booking" then line.amount_minor_units
    else (BigDecimal(@total) * line.percentage / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end

  def due_for(line)
    case line.due_rule
    when "at_confirmation" then [ "at_confirmation", nil ]
    when "days_before_departure" then departure_start ? [ "on_date", departure_start - line.days_before_departure ] : [ "at_confirmation", nil ]
    else [ "on_date", line.due_on ]
    end
  end

  # D-77: units of each service category the booking holds, counted by its per-unit selections.
  def units
    @units ||= @booking.choice_selections.select(&:per_unit?).group_by { |selection| selection.inventory_group.service_category }.transform_values(&:size)
  end

  def departure_start = @booking.client_trip.departure&.starts_on
end
