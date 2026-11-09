# Reverses a returned, cancelled or mistaken supplier payment with a reason
# (SMN-23): negative applications reopen the amounts it settled, and both
# records are kept. Financial records only.
class ReverseSupplierPayment < AgencyCommand
  include SupplierPaymentSupport

  def initialize(agency:, actor:, payment:, reason:, reversed_on: nil)
    @agency = agency
    @actor = actor
    @payment = payment
    @reason = reason.to_s.squish
    @reversed_on = reversed_on
  end

  def call
    ensure_supplier_payment_actor!
    raise Error.new("Reason is required: why the payment is reversed.", code: :invalid) if @reason.empty?

    ActiveRecord::Base.transaction do
      lock_supplier_context!(@payment.departure, @payment.supplier)
      payment = @agency.supplier_payments.includes(:applications, :reversal).find(@payment.id)
      raise Error.new("#{payment.payment_reference} is already reversed.", code: :invalid_state) if payment.reversed?

      reversal = payment.create_reversal!(agency: @agency, reason: @reason, reversed_on: supplier_date!(@reversed_on, "Reversal date"),
        recorded_by: @actor, recorded_at: Clock.current.now)
      payment.applications.group_by(&:amount_due).each do |due, rows|
        net = rows.sum(&:amount_minor_units)
        payment.applications.create!(agency: @agency, amount_due: due, amount_minor_units: -net, recorded_by: @actor, created_at: Clock.current.now) if net.positive?
      end
      audit!(agency: @agency, action: "supplier_payment.reversed", subject: payment, actor: @actor,
        details: { "supplier_payment_id" => payment.id, "supplier_payment_reversal_id" => reversal.id, "reason" => @reason })
      Result.new(status: :updated, record: payment)
    end
  end
end
