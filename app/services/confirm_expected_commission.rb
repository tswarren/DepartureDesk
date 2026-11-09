# Records the supplier's confirmation of an expected commission (SMN-33;
# D-96 (4), step 8 plan question 13): the amount the supplier confirms,
# the expected amount by default. A confirmed commission can no longer be
# overridden. Received, Offset, Adjusted and Reversed wait for a later
# slice. Supplier arrangements or Financial records.
class ConfirmExpectedCommission < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, commission:, amount: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @commission = commission
    @amount = amount
  end

  def call
    ensure_directory_actor!(@actor, @agency, :confirm_commission)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      raise Error.new("Only a confirmed booking's commission can be confirmed.", code: :invalid_state) unless booking.status_confirmed?

      commission = booking.expected_commissions.lock.find(@commission.id)
      raise Error.new("This commission is already confirmed.", code: :invalid_state) unless commission.status == "expected"

      amount = @amount.blank? ? commission.amount_minor_units : parse_amount!(commission.currency)
      previous = commission.amount_minor_units
      commission.update!(status: "confirmed", amount_minor_units: amount, confirmed_by: @actor, confirmed_at: Clock.current.now)
      audit_booking!(booking, "client_booking.commission_confirmed",
        "expected_commission_id" => commission.id, "amount_minor_units" => amount, "previous_amount_minor_units" => previous)
      Result.new(status: :updated, record: commission)
    end
  end

  private

  def parse_amount!(currency)
    MoneyInput.minor_units(@amount, currency)
  rescue MoneyInput::Invalid
    raise Error.new("Confirmed amount must be an amount in #{currency}, such as 1085.00.", code: :invalid)
  end
end
