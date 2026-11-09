# Records a payment the agency made to a supplier (SMN-18; step 8 plan,
# question 9): supplier, payee account if known, date, amount in the
# arrangement currency, method and references, with an SPY- reference,
# applied to that supplier's amounts due on the Departure as staff confirm,
# oldest first by default (SMN-19). What isn't applied stays unapplied on
# the payee account (SMN-22). Payments never cross suppliers. A payment
# changes no cost and no capacity (SMN-03, D-92). Financial records only,
# with no approval step.
class RecordSupplierPayment < AgencyCommand
  include SupplierPaymentSupport

  FIELDS = %w[payee_account_id paid_on amount payment_method bank_reference invoice_reference].freeze

  def initialize(agency:, actor:, departure:, supplier:, attributes:, applications: [])
    @agency = agency
    @actor = actor
    @departure = departure
    @supplier = supplier
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @applications = applications
  end

  def call
    ensure_supplier_payment_actor!

    ActiveRecord::Base.transaction do
      departure, arrangements = lock_supplier_context!(@departure, @supplier)
      currency = arrangements.first.currency
      amount = supplier_money!(@attributes["amount"], currency, "Amount")
      raise Error.new("Amount is required, more than zero.", code: :invalid) if amount.nil? || amount <= 0

      applications = supplier_applications_from(@applications, open_amounts(arrangements), currency)
      raise Error.new("Apply no more than the payment's #{Money.new(amount, currency).format}.", code: :invalid) if applications.sum(&:last) > amount

      payment = departure.supplier_payments.create!(
        agency: @agency, supplier: @supplier, payee_account: payee!, payment_reference: issue_reference!(@agency, ReferenceSequence::SUPPLIER_PAYMENT_NAMESPACE),
        paid_on: supplier_date!(@attributes["paid_on"], "Payment date"), amount_minor_units: amount, currency:,
        payment_method: @attributes["payment_method"].presence_in(SupplierPayment::METHODS) || raise(Error.new("Choose how it was paid.", code: :invalid)),
        bank_reference: @attributes["bank_reference"], invoice_reference: @attributes["invoice_reference"], recorded_by: @actor, recorded_at: Clock.current.now
      )
      applications.each do |due, applied|
        payment.applications.create!(agency: @agency, amount_due: due, amount_minor_units: applied, recorded_by: @actor, created_at: Clock.current.now)
      end
      settle_tasks!(departure, applications.map(&:first))
      audit!(agency: @agency, action: "supplier_payment.recorded", subject: payment, actor: @actor,
        details: { "supplier_payment_id" => payment.id, "payment_reference" => payment.payment_reference, "supplier_id" => @supplier.id,
                   "amount_minor_units" => amount, "applied_minor_units" => applications.sum(&:last), "amount_due_ids" => applications.map { |due, _| due.id } })
      Result.new(status: :created, record: payment)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  # SMN-18: a simple payment needs no payee account; one given must be this supplier's.
  def payee!
    return nil if @attributes["payee_account_id"].blank?

    @supplier.payee_accounts.find_by(id: @attributes["payee_account_id"]) or raise Error.new("Payee account must be one of this supplier's.", code: :invalid)
  end
end
