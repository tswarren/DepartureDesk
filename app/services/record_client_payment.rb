# Records a client payment on a Client Trip (CMN-18, CMN-29; step 8 plan,
# questions 3, 4 and 6): payer, date, amount, route and method, with a
# PAY- reference, applied to the installments staff confirm, oldest first
# by default (CMN-21). What isn't applied is the trip's credit (CMN-23,
# CMN-24). An agency payment issues its receipt in the same transaction,
# numbered without gaps (CMN-55, REF-05); a supplier payment gets none and
# is never agency cash. Financial records only (CMN-19).
class RecordClientPayment < AgencyCommand
  include ClientMoneySupport

  FIELDS = %w[payer_client_id paid_on amount route supplier_id payment_method reference supplier_reference].freeze

  def initialize(agency:, actor:, trip:, attributes:, applications: [])
    @agency = agency
    @actor = actor
    @trip = trip
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @applications = applications
  end

  def call
    ensure_money_actor!

    ActiveRecord::Base.transaction do
      trip = lock_trip!(@trip)
      currency = @departure.operating_currency
      amount = money!(@attributes["amount"], currency, "Amount")
      raise Error.new("Amount is required, more than zero.", code: :invalid) if amount.nil? || amount <= 0

      payment = trip.client_payments.new(agency: @agency, payer: payer!, paid_on: parse_date!(@attributes["paid_on"], "Payment date"),
        amount_minor_units: amount, currency:, route: route!, supplier: supplier!, payment_method: method!,
        reference: @attributes["reference"], supplier_reference: (@attributes["supplier_reference"] if @attributes["route"] == "supplier"),
        recorded_by: @actor, recorded_at: Clock.current.now)
      applications = applications_from(@applications, trip_installments(trip), currency)
      raise Error.new("Apply no more than the payment's #{Money.new(amount, currency).format}.", code: :invalid) if applications.sum(&:last) > amount

      payment.payment_reference = issue_reference!(@agency, ReferenceSequence::CLIENT_PAYMENT_NAMESPACE)
      payment.save!
      apply!(payment, applications)
      receipt = issue_receipt!(payment, applications) if payment.agency_route?
      audit!(agency: @agency, action: "client_payment.recorded", subject: payment, actor: @actor,
        details: { "client_payment_id" => payment.id, "payment_reference" => payment.payment_reference, "route" => payment.route,
                   "amount_minor_units" => amount, "applied_minor_units" => applications.sum(&:last), "receipt_number" => receipt&.receipt_number })
      Result.new(status: :created, record: payment)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def payer!
    @agency.clients.find_by(id: @attributes["payer_client_id"]) or raise Error.new("Payer must be one of the agency's clients.", code: :invalid)
  end

  def route!
    @attributes["route"].presence_in(ClientPayment::ROUTES) or raise Error.new("Choose who received the payment.", code: :invalid)
  end

  def method!
    @attributes["payment_method"].presence_in(ClientPayment::METHODS) or raise Error.new("Choose how it was paid.", code: :invalid)
  end

  # CMN-18: a supplier-direct payment names a supplier with an arrangement on the trip's Departure.
  def supplier!
    return nil unless @attributes["route"] == "supplier"

    @departure.supplier_arrangements.live.map(&:supplier).find { |supplier| supplier.id == @attributes["supplier_id"] } or
      raise Error.new("Choose the supplier that received it: one with an arrangement on this Departure.", code: :invalid)
  end

  def issue_receipt!(payment, applications)
    payment.create_receipt!(
      agency: @agency, receipt_number: issue_reference!(@agency, ReferenceSequence::RECEIPT_NAMESPACE), departure: @departure,
      payer_name: payment.payer.source.display_name, amount_minor_units: payment.amount_minor_units, currency: payment.currency,
      paid_on: payment.paid_on, payment_method: payment.payment_method, reference: payment.reference, issued_at: Clock.current.now,
      applied: applications.map do |installment, amount|
        { "booking_reference" => installment.client_charge.client_booking.booking_reference, "installment" => installment.description,
          "due_on" => installment.due_on.iso8601, "amount_minor_units" => amount }
      end
    )
  end
end
