# A Client Trip's client money, read from its records (S-28; CMN-06,
# CMN-23, CMN-28, CMN-29, SMN-27): each confirmed booking's charge and
# installments, its payments by route, the credit not yet applied, the
# supplier-held funds due to the agency, and the receivable. Nothing here
# is stored.
class TripMoney
  attr_reader :trip

  BOOKINGS = { client_charge: [ :lines, { installments: { applications: :client_payment } } ] }.freeze
  PAYMENTS = [ :payer, :supplier, :reversal, :receipt, :recorded_by, { applications: { installment: { client_charge: :client_booking } } } ].freeze
  # For listing several trips at once without a query per trip.
  PRELOAD = { client_bookings: BOOKINGS, client_payments: PAYMENTS }.freeze

  def initialize(trip)
    @trip = trip
  end

  def bookings
    @bookings ||= loaded(:client_bookings) { trip.client_bookings.includes(BOOKINGS) }.select(&:client_charge)
  end

  def payments
    @payments ||= loaded(:client_payments) { trip.client_payments.includes(PAYMENTS) }.to_a
  end

  def currency = trip.departure&.operating_currency

  def installments
    bookings.flat_map { |booking| booking.client_charge.installments }.sort_by { |installment| [ installment.due_on, installment.client_charge.client_booking.booking_reference, installment.position ] }
  end

  def open_installments = installments.reject(&:paid?)

  # CMN-06: still due from the client, across the trip's bookings and routes.
  def receivable_minor_units = bookings.sum { |booking| booking.client_charge.remainder_minor_units }
  def credit_minor_units = payments.sum(&:credit_minor_units)
  def agency_cash_minor_units = payments.select(&:agency_route?).reject(&:reversed?).sum(&:amount_minor_units)
  def supplier_route_minor_units = payments.select(&:supplier_route?).reject(&:reversed?).sum(&:amount_minor_units)

  # SMN-27: what suppliers collected on lines owed to the agency (every Slice 1 line).
  def supplier_held_minor_units = payments.select(&:supplier_route?).sum(&:applied_minor_units)

  def loaded(name)
    trip.association(name).loaded? ? trip.public_send(name).to_a : yield
  end

  # CMN-21: the payment split oldest installment first, for staff to review.
  def proposed_applications(amount_minor_units)
    left = amount_minor_units.to_i
    open_installments.to_h do |installment|
      take = [ left, installment.open_minor_units ].min
      left -= take
      [ installment.id, take ]
    end
  end
end
