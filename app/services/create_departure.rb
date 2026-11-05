class CreateDeparture < AgencyCommand
  include DepartureCommandSupport
  include DepartureReferenceIssuance

  def initialize(agency:, actor:, attributes:)
    @agency = agency
    @actor = actor
    @attributes = attributes.to_h.with_indifferent_access
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      attrs = resolved_attributes

      departure = @agency.departures.create!(
        departure_reference: issue_departure_reference!(@agency),
        name: attrs[:name],
        description: attrs[:description],
        starts_on: attrs[:starts_on],
        ends_on: attrs[:ends_on],
        time_zone: attrs[:time_zone],
        operating_currency: attrs[:operating_currency],
        hold_duration_days: attrs[:hold_duration_days],
        installment_buffer_days: attrs[:installment_buffer_days]
      )
      # OPS-12: the creator starts as the team's default task owner.
      departure.team_members.create!(agency: @agency, agency_user: @actor, default_task_owner: true)
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

  def self.proposed_attributes(agency:, actor:)
    {
      time_zone: agency.default_timezone,
      operating_currency: agency.default_currency
    }
  end

  private

  def resolved_attributes
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

    {
      name: normalize_name(raw_attribute(:name)),
      description: supplied?(:description) ? normalize_description(raw_attribute(:description)) : nil,
      starts_on:,
      ends_on:,
      time_zone:,
      operating_currency: currency
    }.merge(normalize_overrides)
  end

  def audit_details(departure)
    {
      "departure_id" => departure.id,
      "departure_reference" => departure.departure_reference,
      "sales_status" => departure.sales_status,
      "operating_decision" => departure.operating_decision,
      "completion_status" => departure.completion_status,
      "name" => departure.name,
      "starts_on" => departure.starts_on&.iso8601,
      "ends_on" => departure.ends_on&.iso8601,
      "time_zone" => departure.time_zone,
      "operating_currency" => departure.operating_currency,
      "hold_duration_days" => departure.hold_duration_days,
      "installment_buffer_days" => departure.installment_buffer_days,
      "default_task_owner_id" => @actor.id
    }
  end
end
