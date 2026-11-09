# Shared steps for client money commands (CMN-18, CMN-19, CMN-21, CMN-23,
# CMN-27). They need Financial records and lock agency, Departure, then the
# trip, so two payments on one trip are applied one after the other.
module ClientMoneySupport
  include ReferenceIssuance

  private

  def ensure_money_actor!
    ensure_directory_actor!(@actor, @agency, :manage_client_money)
    ensure_active_agency!(@agency)
  end

  def lock_trip!(trip)
    @agency.lock!
    record = @agency.client_trips.find(trip.id)
    raise AgencyCommand::Error.new("Link the trip to a Departure before recording money on it.", code: :invalid_state) if record.departure_id.nil?

    @departure = @agency.departures.lock.find(record.departure_id)
    @agency.client_trips.lock.find(trip.id)
  end

  # The trip's installments, oldest due first, with what is still open.
  def trip_installments(trip)
    Installment.joins(client_charge: :client_booking).where(client_bookings: { client_trip_id: trip.id })
      .includes(applications: :client_payment, client_charge: :client_booking).to_a
      .sort_by { |installment| [ installment.due_on, installment.client_charge.client_booking.booking_reference, installment.position ] }
  end

  # [[installment, amount], ...] from staff's {installment_id => amount} rows,
  # each within what the installment still has open.
  def applications_from(rows, installments, currency)
    by_id = installments.index_by(&:id)
    Array(rows).filter_map do |row|
      row = row.to_h.stringify_keys
      amount = money!(row["amount"], currency, "Amount applied") or next
      next if amount.zero?

      installment = by_id[row["installment_id"]] or raise AgencyCommand::Error.new("Each installment must be on this trip.", code: :invalid)
      if amount > installment.open_minor_units
        raise AgencyCommand::Error.new("#{installment.description} has #{Money.new(installment.open_minor_units, currency).format} open; apply no more than that.", code: :invalid)
      end
      [ installment, amount ]
    end
  end

  def money!(value, currency, label)
    MoneyInput.minor_units(value, currency)
  rescue MoneyInput::Invalid
    raise AgencyCommand::Error.new("#{label} must be an amount in #{currency}, such as 500.00.", code: :invalid)
  end

  def parse_date!(value, label)
    date = Date.iso8601(value.to_s)
    raise AgencyCommand::Error.new("#{label} can't be in the future.", code: :invalid) if date > Clock.current.today_in(@agency.default_timezone)

    date
  rescue Date::Error
    raise AgencyCommand::Error.new("#{label} must be a date, such as 2027-01-12.", code: :invalid)
  end

  def apply!(payment, applications)
    applications.map do |installment, amount|
      payment.applications.create!(agency: @agency, installment:, amount_minor_units: amount, recorded_by: @actor, created_at: Clock.current.now)
    end
  end
end
