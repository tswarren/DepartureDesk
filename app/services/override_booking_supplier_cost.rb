# Overrides a confirmed booking's proposed supplier cost or expected
# commission (SUP-35, SMN-32). Needs Supplier arrangements or Financial
# records. A cost line can change only until an amount due posts against
# it; a commission only while it is Expected. The proposal stays on record.
class OverrideBookingSupplierCost < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, amount:, cost_line: nil, commission: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @amount = amount
    @cost_line = cost_line
    @commission = commission
  end

  def call
    ensure_directory_actor!(@actor, @agency, :override_booking_supplier_cost)
    ensure_active_agency!(@agency)

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      raise Error.new("Only a confirmed booking's supplier cost can be overridden.", code: :invalid_state) unless booking.status_confirmed?

      record = @cost_line ? booking.cost_lines.lock.find(@cost_line.id) : booking.expected_commissions.lock.find(@commission.id)
      amount = parse_amount(record.currency)
      previous = record.amount_minor_units
      return Result.new(status: :noop, record:) if amount == previous

      if record.is_a?(CostLine)
        raise Error.new("An amount due has posted against this cost line, so it can't change.", code: :invalid_state) if record.posted?

        record.update!(rate_minor_units: amount, amount_minor_units: amount)
      else
        raise Error.new("Only an expected commission can be overridden.", code: :invalid_state) unless record.status == "expected"

        record.update!(amount_minor_units: amount, overridden_by: @actor, overridden_at: Clock.current.now)
      end
      audit_booking!(booking, "client_booking.supplier_cost_overridden",
        "record_type" => record.class.name, "record_id" => record.id, "amount_minor_units" => amount, "previous_amount_minor_units" => previous)
      Result.new(status: :updated, record:)
    end
  end

  private

  def parse_amount(currency)
    amount = MoneyInput.minor_units(@amount, currency)
    raise Error.new("Amount must be an amount in #{currency}.", code: :invalid) if amount.nil? || amount.negative?

    amount
  rescue MoneyInput::Invalid
    raise Error.new("Amount must be an amount in #{currency}.", code: :invalid)
  end
end
