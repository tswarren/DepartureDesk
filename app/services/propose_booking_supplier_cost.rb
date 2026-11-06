# Proposes a booking's supplier cost and expected commission for one unit
# from its group's supplier rate table, at the actual occupancy (SUP-35,
# SMN-32, D-75). Booking confirmation calls it in build step 6 and staff
# may override the result; nothing is posted here.
#
# Guests are given in occupancy order, each with its traveler type (or
# nil). One guest uses the single-occupancy row; otherwise the n-th guest
# uses the guest_n row. A row for the guest's traveler type wins over the
# row for any type. Gross cost is base fare plus non-commissionable fees
# plus taxes, less discount; commission stays separate (FIN-03).
#
# Rounding (ADR 0001): a commission rate is applied to its base in exact
# decimal arithmetic and rounded half up to the currency's minor unit,
# once per guest. A stated commission amount is used as is.
class ProposeBookingSupplierCost
  Line = Data.define(:occupancy_position, :traveler_type, :rate_line, :base_fare, :non_commissionable_fees, :taxes, :discount, :gross, :commission)
  Proposal = Data.define(:currency, :lines, :missing) do
    def gross = lines.sum(&:gross)
    def commission = lines.sum(&:commission)
    def net = gross - commission
    def complete? = missing.empty?
  end

  def initialize(group:, guests:)
    @group = group
    @guests = Array(guests)
  end

  def call
    raise ArgumentError, "A unit needs at least one guest." if @guests.empty?

    rates = @group.rate_lines.to_a
    lines = []
    missing = []
    positions.each_with_index do |position, index|
      traveler_type = @guests[index]
      rate = rates.find { |line| line.occupancy_position == position && line.traveler_type_id == traveler_type&.id } ||
        rates.find { |line| line.occupancy_position == position && line.traveler_type_id.nil? }
      rate ? lines << line_for(position, traveler_type, rate) : missing << position
    end
    Proposal.new(currency: @group.supplier_arrangement.currency, lines:, missing:)
  end

  private

  def positions
    @guests.one? ? [ "single" ] : (1..@guests.size).map { |n| "guest_#{n}" }
  end

  def line_for(position, traveler_type, rate)
    gross = rate.base_fare_minor_units + rate.non_commissionable_fees_minor_units + rate.taxes_minor_units - rate.discount_minor_units
    Line.new(
      occupancy_position: position, traveler_type:, rate_line: rate,
      base_fare: rate.base_fare_minor_units, non_commissionable_fees: rate.non_commissionable_fees_minor_units,
      taxes: rate.taxes_minor_units, discount: rate.discount_minor_units, gross:, commission: commission_for(rate)
    )
  end

  def commission_for(rate)
    return rate.commission_minor_units.to_i if rate.commission_rate.nil?

    base = rate.base_fare_minor_units
    base -= rate.discount_minor_units if rate.commission_base == "base_fare_less_discount"
    (BigDecimal(base) * rate.commission_rate / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end
end
