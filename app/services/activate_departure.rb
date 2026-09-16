class ActivateDeparture < AgencyCommand
  include DepartureCommandSupport
  include DepartureReferenceIssuance

  def initialize(agency:, actor:, departure:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_agency!
      departure = lock_departure!
      return Result.new(status: :noop, record: departure) if departure.active?
      if departure.departed?
        raise Error.new("A departed departure cannot be activated.", code: :invalid_state)
      end
      unless departure.draft?
        raise Error.new("That departure cannot be activated.", code: :invalid_state)
      end

      ensure_current_lock_version!(departure)
      office = lock_office!(departure.responsible_office)
      user = lock_agency_user!(departure.responsible_agency_user)
      ensure_activation_complete!(departure, office, user)

      first_activation = departure.departure_reference.blank?
      if first_activation
        departure.departure_reference = issue_departure_reference!(@agency)
        departure.first_activated_at = Time.current
      end
      departure.status = "active"
      departure.save!
      audit!(
        agency: @agency,
        action: "departure.activated",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "first_activation" => first_activation,
          "starts_on" => departure.starts_on&.iso8601,
          "ends_on" => departure.ends_on&.iso8601,
          "time_zone" => departure.time_zone,
          "operating_currency" => departure.operating_currency,
          "responsible_office_id" => departure.responsible_office_id,
          "responsible_agency_user_id" => departure.responsible_agency_user_id
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def ensure_activation_complete!(departure, office, user)
    blockers = []
    blockers << "Enter a name." if departure.name.blank?
    if departure.starts_on.blank? || departure.ends_on.blank?
      blockers << "Enter a start date and an end date."
    elsif departure.starts_on > departure.ends_on
      blockers << "End date must be on or after the start date."
    end
    begin
      raise Error.new("Enter a recognized time zone.", code: :invalid) if departure.time_zone.blank?

      TZInfo::Timezone.get(departure.time_zone)
    rescue TZInfo::InvalidTimezoneIdentifier
      blockers << "Enter a recognized time zone."
    end
    begin
      raise Error.new("Enter a supported operating currency.", code: :invalid) if departure.operating_currency.blank?

      Money::Currency.find(departure.operating_currency)
    rescue Money::Currency::UnknownCurrency
      blockers << "Enter a supported operating currency."
    end
    if office.nil?
      blockers << "Choose an active responsible office."
    elsif !office.active?
      raise Error.new("That office is not active.", code: :invalid_state)
    end
    if user.nil?
      blockers << "Choose an active responsible agency user."
    elsif !user.active?
      raise Error.new("That agency user is not active.", code: :invalid_state)
    end
    raise Error.new(blockers.to_sentence, code: :invalid) if blockers.any?
  end
end
