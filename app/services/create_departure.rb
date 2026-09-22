class CreateDeparture < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, attributes:, current_office: nil)
    @agency = agency
    @actor = actor
    @attributes = attributes.to_h.with_indifferent_access
    @current_office = current_office
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      attrs = resolved_attributes
      raise Error.new("Choose a responsible office.", code: :invalid) if attrs[:responsible_office_id].blank?

      office = resolve_office!(attrs[:responsible_office_id])
      user = resolve_agency_user!(attrs[:responsible_agency_user_id])
      locked_office = lock_office!(office)
      locked_user = lock_agency_user!(user)
      ensure_active_target!(locked_office, "That office is not active.") if office.present?
      ensure_active_target!(locked_user, "That agency user is not active.") if user.present?

      departure = @agency.departures.create!(
        name: attrs[:name],
        description: attrs[:description],
        target_timing_text: attrs[:target_timing_text],
        starts_on: attrs[:starts_on],
        ends_on: attrs[:ends_on],
        time_zone: attrs[:time_zone],
        operating_currency: attrs[:operating_currency],
        responsible_office: locked_office,
        responsible_agency_user: locked_user,
        status: "draft"
      )
      audit!(
        agency: @agency,
        action: "departure.created",
        subject: departure,
        actor: @actor,
        details: audit_details(departure)
      )
      Result.new(status: :created, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  def self.proposed_attributes(agency:, actor:, current_office: nil)
    office = active_agency_office(agency, current_office) || active_agency_office(agency, actor&.default_office)
    {
      responsible_office_id: office&.id,
      responsible_agency_user_id: actor&.id,
      time_zone: agency.default_timezone,
      operating_currency: agency.default_currency
    }
  end

  def self.active_agency_office(agency, office)
    return if office.blank?
    return unless office.agency_id == agency.id
    return unless office.active?

    office
  end

  private

  def resolved_attributes
    office_id = if supplied?(:responsible_office_id)
      raw_attribute(:responsible_office_id)
    else
      copy_office&.id
    end
    user_id = if supplied?(:responsible_agency_user_id)
      raw_attribute(:responsible_agency_user_id)
    else
      @actor&.id
    end
    time_zone = if supplied?(:time_zone)
      normalize_time_zone(raw_attribute(:time_zone))
    else
      @agency.default_timezone
    end
    currency = if supplied?(:operating_currency)
      normalize_currency(raw_attribute(:operating_currency))
    else
      @agency.default_currency
    end
    starts_on, ends_on = if supplied?(:starts_on) || supplied?(:ends_on)
      normalize_dates(raw_attribute(:starts_on), raw_attribute(:ends_on))
    else
      [ nil, nil ]
    end
    target_timing_text = if supplied?(:target_timing_text)
      normalize_target_timing_text(raw_attribute(:target_timing_text))
    else
      nil
    end

    {
      name: normalize_name(raw_attribute(:name)),
      description: supplied?(:description) ? normalize_description(raw_attribute(:description)) : nil,
      target_timing_text:,
      starts_on:,
      ends_on:,
      time_zone:,
      operating_currency: currency,
      responsible_office_id: office_id,
      responsible_agency_user_id: user_id
    }
  end

  def copy_office
    self.class.active_agency_office(@agency, @current_office) ||
      self.class.active_agency_office(@agency, @actor&.default_office)
  end

  def audit_details(departure)
    {
      "departure_id" => departure.id,
      "status" => departure.status,
      "name" => departure.name,
      "target_timing_text" => departure.target_timing_text,
      "starts_on" => departure.starts_on&.iso8601,
      "ends_on" => departure.ends_on&.iso8601,
      "time_zone" => departure.time_zone,
      "operating_currency" => departure.operating_currency,
      "responsible_office_id" => departure.responsible_office_id,
      "responsible_agency_user_id" => departure.responsible_agency_user_id
    }
  end
end
