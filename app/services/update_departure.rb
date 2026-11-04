class UpdateDeparture < AgencyCommand
  include DepartureCommandSupport

  EDITABLE_FIELDS = %i[name description starts_on ends_on time_zone operating_currency].freeze
  DEPARTED_EDITABLE_FIELDS = %i[name description].freeze

  def initialize(agency:, actor:, departure:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @attributes = attributes.to_h.with_indifferent_access
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)
    attrs = normalized_attributes

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:manage_departures)
      departure = lock_departure!
      ensure_current_lock_version!(departure)
      reject_departed_operating_changes!(departure, attrs)
      ensure_non_draft_completeness!(departure, attrs)
      return Result.new(status: :noop, record: departure) if unchanged?(departure, attrs)

      departure.update!(attrs)
      audit!(
        agency: @agency,
        action: "departure.updated",
        subject: departure,
        actor: @actor,
        details: {
          "departure_id" => departure.id,
          "changed_fields" => changed_fields(departure, attrs)
        }
      )
      Result.new(status: :updated, record: departure)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalized_attributes
    starts_on, ends_on = normalize_dates(raw_attribute(:starts_on), raw_attribute(:ends_on))
    {
      name: normalize_name(raw_attribute(:name)),
      description: normalize_description(raw_attribute(:description)),
      starts_on:,
      ends_on:,
      time_zone: normalize_time_zone(raw_attribute(:time_zone)),
      operating_currency: normalize_currency(raw_attribute(:operating_currency))
    }
  end

  def reject_departed_operating_changes!(departure, attrs)
    return unless departure.departed?

    forbidden = (EDITABLE_FIELDS - DEPARTED_EDITABLE_FIELDS).select do |field|
      departure.public_send(field) != attrs[field]
    end
    return if forbidden.empty?

    raise Error.new("That field cannot be changed after the departure has departed.", code: :invalid_state)
  end

  def unchanged?(departure, attrs)
    attrs.all? { |key, value| departure.public_send(key) == value }
  end

  def changed_fields(departure, attrs)
    attrs.keys.select { |key| departure.saved_change_to_attribute?(key) }.map(&:to_s)
  end
end
