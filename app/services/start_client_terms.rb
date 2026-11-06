# Starts a Departure's client terms (BKG-28, D-76): version 1 copying the
# agency's reusable wording, or, with a source Departure, a copy of that
# Departure's current terms (wording, tier override and payment schedule)
# that is independent of its source. Copying replaces an unlocked version's
# contents; a Departure whose terms a booking has accepted can't be reset.
class StartClientTerms < AgencyCommand
  include ClientTermsCommandSupport

  def initialize(agency:, actor:, departure:, source_departure_id: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @source_departure_id = source_departure_id
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      source = source_terms(departure)
      version = departure.client_terms_versions.lock.max_by(&:version_number)
      raise Error.new("These terms are locked: a booking has accepted them.", code: :invalid_state) if version&.locked?
      return Result.new(status: :noop, record: version) if version && source.nil?

      version ||= departure.client_terms_versions.new(agency: @agency, version_number: 1)
      creating = version.new_record?
      if source
        copy_from!(version, departure, source)
      else
        version.update!(agency_wording: @agency.client_terms_wording)
      end
      audit_departure!(departure, source ? "departure.client_terms_copied" : "departure.client_terms_created",
        { "client_terms_version_id" => version.id, "version_number" => version.version_number, "created" => creating,
          "copied_from_departure_id" => source&.departure_id }.compact)
      Result.new(status: creating ? :created : :updated, record: version)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def source_terms(departure)
    return nil if @source_departure_id.blank?

    source = @agency.departures.where.not(id: departure.id).find_by(id: parse_optional_uuid(@source_departure_id, "Departure"))
    raise Error.new("Choose another departure of this agency to copy from.", code: :invalid) if source.nil?

    source.current_client_terms or raise Error.new("That departure has no client terms to copy.", code: :invalid)
  end

  def copy_from!(version, departure, source)
    if source.departure.operating_currency != departure.operating_currency
      raise Error.new("Copy terms only from a departure in the same currency.", code: :invalid)
    end

    version.update!(agency_wording: source.agency_wording, departure_wording: source.departure_wording,
      overrides_cancellation_tiers: source.overrides_cancellation_tiers, copied_from_departure: source.departure)
    version.own_cancellation_tiers.delete_all(:delete_all)
    version.schedule_lines.delete_all(:delete_all)
    source.own_cancellation_tiers.each do |tier|
      version.own_cancellation_tiers.create!(tier.attributes.slice(*%w[min_days_before_departure charge_kind percentage amount_minor_units currency service_category]).merge(agency: @agency))
    end
    source.schedule_lines.each do |line|
      version.schedule_lines.create!(line.attributes.slice(*%w[
        description basis service_category amount_minor_units percentage currency due_rule days_before_departure due_on counts_as_acceptance position
      ]).merge(agency: @agency))
    end
  end
end
