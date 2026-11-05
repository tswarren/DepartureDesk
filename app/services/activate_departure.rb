class ActivateDeparture < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      if departure.departed?
        raise Error.new("A departed departure cannot be activated.", code: :invalid_state)
      end
      return Result.new(status: :noop, record: departure) if departure.ready_to_sell?

      ensure_current_lock_version!(departure)
      ensure_activation_complete!(departure)

      departure.sales_status = "ready_to_sell"
      departure.save!
      audit!(
        agency: @agency,
        action: "departure.activated",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "starts_on" => departure.starts_on&.iso8601,
          "ends_on" => departure.ends_on&.iso8601,
          "time_zone" => departure.time_zone,
          "operating_currency" => departure.operating_currency
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_activation_complete!(departure)
    blockers = []
    blockers << "Enter a name." if departure.name.blank?
    if departure.starts_on.blank? || departure.ends_on.blank?
      blockers << "Enter a start date and an end date."
    elsif departure.starts_on > departure.ends_on
      blockers << "End date must be on or after the start date."
    end
    blockers << "Enter a recognized time zone." if time_zone_invalid?(departure.time_zone)
    blockers << "Enter a supported operating currency." if currency_invalid?(departure.operating_currency)
    raise Error.new(blockers.to_sentence, code: :invalid) if blockers.any?
  end

  def time_zone_invalid?(value)
    return true if value.blank?

    TZInfo::Timezone.get(value)
    false
  rescue TZInfo::InvalidTimezoneIdentifier
    true
  end

  def currency_invalid?(value)
    return true if value.blank?

    Money::Currency.find(value)
    false
  rescue Money::Currency::UnknownCurrency
    true
  end
end
