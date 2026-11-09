# Reverses a client payment, such as a bounced check, with a reason
# (CMN-27, D-96 (1)): negative applications reopen the installments it
# settled, and both records are kept. A receipt stays issued; the reversal
# is shown beside it, never on it (CMN-55). Financial records only.
class ReverseClientPayment < AgencyCommand
  include ClientMoneySupport

  def initialize(agency:, actor:, payment:, reason:, reversed_on: nil)
    @agency = agency
    @actor = actor
    @payment = payment
    @reason = reason.to_s.squish
    @reversed_on = reversed_on
  end

  def call
    ensure_money_actor!
    raise Error.new("Reason is required: why the payment is reversed.", code: :invalid) if @reason.empty?

    ActiveRecord::Base.transaction do
      lock_trip!(@payment.client_trip)
      payment = @agency.client_payments.includes(:applications, :reversal).find(@payment.id)
      raise Error.new("#{payment.payment_reference} is already reversed.", code: :invalid_state) if payment.reversed?

      reversed_on = @reversed_on.present? ? parse_date!(@reversed_on, "Reversal date") : Clock.current.today_in(@agency.default_timezone)
      reversal = payment.create_reversal!(agency: @agency, reason: @reason, reversed_on:, recorded_by: @actor, recorded_at: Clock.current.now)
      payment.applications.group_by(&:installment).each do |installment, rows|
        net = rows.sum(&:amount_minor_units)
        payment.applications.create!(agency: @agency, installment:, amount_minor_units: -net, recorded_by: @actor, created_at: Clock.current.now) if net.positive?
      end
      audit!(agency: @agency, action: "client_payment.reversed", subject: payment, actor: @actor,
        details: { "client_payment_id" => payment.id, "client_payment_reversal_id" => reversal.id, "reason" => @reason })
      Result.new(status: :updated, record: payment)
    end
  end
end
