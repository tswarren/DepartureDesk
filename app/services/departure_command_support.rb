module DepartureCommandSupport
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  STALE_MESSAGE = "This record changed. Reload it and try again."
  REASON_LIMIT = 500

  private

  def ensure_departure_actor!(permission)
    ensure_directory_actor!(@actor, @agency, permission)
    ensure_active_agency!(@agency)
  end

  def lock_agency!
    @agency.lock!
  end

  def lock_authorized_agency!(permission)
    lock_agency!
    @agency.reload
    ensure_active_agency!(@agency)
    @actor = @agency.agency_users.find_by(id: @actor&.id)
    ensure_directory_actor!(@actor, @agency, permission)
  end

  def lock_system_agency!
    lock_agency!
    @agency.reload
    ensure_active_agency!(@agency)
  end

  def lock_departure!
    @agency.departures.lock.find(@departure.id)
  end

  def reject_currency_change_with_monetary_definitions!(departure, currency, verb: "changed")
    return if departure.operating_currency == currency
    cost_exists = SupplierCostDefinition.where(agency_id: @agency.id, departure_id: departure.id).exists?
    price_exists = ServiceOfferPriceDefinition.joins(:service_offer_version).where(
      agency_id: @agency.id,
      departure_id: departure.id,
      service_offer_versions: { status: "draft" }
    ).exists? || PackagePriceDefinition.joins(:package_version).where(
      agency_id: @agency.id,
      departure_id: departure.id,
      package_versions: { status: "draft" }
    ).exists?
    return unless cost_exists || price_exists

    raise AgencyCommand::Error.new(
      "Operating currency cannot be #{verb} after Supplier cost or Client price definitions exist.",
      code: :invalid_state
    )
  end

  def ensure_current_lock_version!(record)
    if @lock_version.nil? || record.lock_version != @lock_version.to_i
      raise AgencyCommand::Error.new(STALE_MESSAGE, code: :conflict)
    end
  end

  def supplied?(key)
    @attributes.key?(key)
  end

  def raw_attribute(key)
    @attributes[key]
  end

  def parse_optional_uuid(value, label)
    return nil if value.blank?
    unless value.to_s.match?(UUID_FORMAT)
      raise AgencyCommand::Error.new("#{label} is not valid.", code: :invalid)
    end

    value.to_s
  end

  def parse_date(value, label)
    return nil if value.blank?
    return value if value.is_a?(Date)
    return value.to_date if value.respond_to?(:to_date) && (value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone))

    Date.iso8601(value.to_s)
  rescue Date::Error, ArgumentError
    raise AgencyCommand::Error.new("#{label} is not a valid date.", code: :invalid)
  end

  def normalize_name(value)
    name = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a name.", code: :invalid) if name.blank?
    if name.length > Departure::NAME_LIMIT
      raise AgencyCommand::Error.new("Name must be #{Departure::NAME_LIMIT} characters or fewer.", code: :invalid)
    end

    name
  end

  def normalize_description(value)
    description = value.to_s.strip.presence
    if description && description.length > Departure::DESCRIPTION_LIMIT
      raise AgencyCommand::Error.new("Description must be #{Departure::DESCRIPTION_LIMIT} characters or fewer.", code: :invalid)
    end

    description
  end

  def normalize_time_zone(value)
    zone = value.to_s.strip.presence
    return if zone.blank?

    TZInfo::Timezone.get(zone)
    zone
  rescue TZInfo::InvalidTimezoneIdentifier
    raise AgencyCommand::Error.new("Enter a recognized time zone.", code: :invalid)
  end

  def normalize_currency(value)
    code = value.to_s.strip.upcase.presence
    return if code.blank?
    unless code.match?(Agency::CURRENCY_FORMAT)
      raise AgencyCommand::Error.new("Enter a supported operating currency.", code: :invalid)
    end

    Money::Currency.find(code)
    code
  rescue Money::Currency::UnknownCurrency
    raise AgencyCommand::Error.new("Enter a supported operating currency.", code: :invalid)
  end

  def normalize_dates(starts_on, ends_on)
    start_date = parse_date(starts_on, "Start date")
    end_date = parse_date(ends_on, "End date")
    if start_date.blank? ^ end_date.blank?
      raise AgencyCommand::Error.new("Enter both a start date and an end date, or leave both blank.", code: :invalid)
    end
    if start_date.present? && end_date.present? && start_date > end_date
      raise AgencyCommand::Error.new("End date must be on or after the start date.", code: :invalid)
    end

    [ start_date, end_date ]
  end

  def resolve_office!(id)
    uuid = parse_optional_uuid(id, "Office")
    return if uuid.blank?
    office = @agency.offices.find_by(id: uuid)
    raise AgencyCommand::Error.new("That office was not found.", code: :not_found) if office.nil?

    office
  end

  def resolve_agency_user!(id)
    uuid = parse_optional_uuid(id, "Agency user")
    return if uuid.blank?
    user = @agency.agency_users.find_by(id: uuid)
    raise AgencyCommand::Error.new("That agency user was not found.", code: :not_found) if user.nil?

    user
  end

  def lock_office!(office)
    return if office.nil?

    @agency.offices.lock.find(office.id)
  end

  def lock_agency_user!(user)
    return if user.nil?

    @agency.agency_users.lock.find(user.id)
  end

  def ensure_active_target!(record, message)
    return if record.nil?
    return if record.active?

    raise AgencyCommand::Error.new(message, code: :invalid_state)
  end

  def normalize_reason(value)
    reason = value.to_s.strip
    raise AgencyCommand::Error.new("Enter a reason.", code: :invalid) if reason.blank?
    if reason.length > REASON_LIMIT
      raise AgencyCommand::Error.new("Reason must be #{REASON_LIMIT} characters or fewer.", code: :invalid)
    end

    reason
  end

  def ensure_non_draft_completeness!(departure, attrs)
    return if departure.draft?

    if attrs[:starts_on].blank? || attrs[:ends_on].blank?
      raise AgencyCommand::Error.new("Enter a start date and an end date.", code: :invalid)
    end
    if attrs[:time_zone].blank?
      raise AgencyCommand::Error.new("Enter a recognized time zone.", code: :invalid)
    end
    if attrs[:operating_currency].blank?
      raise AgencyCommand::Error.new("Enter a supported operating currency.", code: :invalid)
    end
    if departure.responsible_office_id.blank? || departure.responsible_agency_user_id.blank?
      raise AgencyCommand::Error.new("Active and departed departures require a responsible office and agency user.", code: :invalid)
    end
  end

  def command_error_from(error)
    raise AgencyCommand::Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
