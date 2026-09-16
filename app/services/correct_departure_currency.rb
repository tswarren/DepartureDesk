class CorrectDepartureCurrency < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, operating_currency:, reason:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @operating_currency = operating_currency
    @reason = reason
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      ensure_current_lock_version!(departure)
      unless departure.departed?
        raise Error.new("Only a departed departure can receive a currency correction.", code: :invalid_state)
      end
      reason = normalize_reason(@reason)
      currency = normalize_currency(@operating_currency)
      raise Error.new("Enter a supported operating currency.", code: :invalid) if currency.blank?
      return Result.new(status: :noop, record: departure) if departure.operating_currency == currency

      prior_currency = departure.operating_currency
      departure.update!(operating_currency: currency)
      audit!(
        agency: @agency,
        action: "departure.currency_corrected",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "reason" => reason,
          "prior_operating_currency" => prior_currency,
          "operating_currency" => departure.operating_currency
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
