class CorrectDepartureSchedule < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, departure:, starts_on:, ends_on:, time_zone:, reason:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @starts_on = starts_on
    @ends_on = ends_on
    @time_zone = time_zone
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
        raise Error.new("Only a departed departure can receive a schedule correction.", code: :invalid_state)
      end
      reason = normalize_reason(@reason)
      attrs = normalized_schedule
      return Result.new(status: :noop, record: departure) if unchanged?(departure, attrs)

      previous = {
        "starts_on" => departure.starts_on&.iso8601,
        "ends_on" => departure.ends_on&.iso8601,
        "time_zone" => departure.time_zone
      }
      departure.update!(attrs)
      changed_fields = attrs.keys.select { |key| departure.saved_change_to_attribute?(key) }.map(&:to_s)
      audit!(
        agency: @agency,
        action: "departure.schedule_corrected",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "departure_reference" => departure.departure_reference,
          "reason" => reason,
          "changed_fields" => changed_fields,
          "prior_starts_on" => previous["starts_on"],
          "prior_ends_on" => previous["ends_on"],
          "prior_time_zone" => previous["time_zone"],
          "starts_on" => departure.starts_on&.iso8601,
          "ends_on" => departure.ends_on&.iso8601,
          "time_zone" => departure.time_zone
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalized_schedule
    starts_on, ends_on = normalize_dates(@starts_on, @ends_on)
    time_zone = normalize_time_zone(@time_zone)
    if starts_on.blank? || ends_on.blank?
      raise Error.new("Enter a start date and an end date.", code: :invalid)
    end
    if time_zone.blank?
      raise Error.new("Enter a recognized time zone.", code: :invalid)
    end

    { starts_on:, ends_on:, time_zone: }
  end

  def unchanged?(departure, attrs)
    attrs.all? { |key, value| departure.public_send(key) == value }
  end
end
