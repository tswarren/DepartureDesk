# Starts the next version of a Departure's client terms once its current
# version is locked by an acceptance (BKG-28, D-76). The new version copies
# the wording, the payment schedule and any tier override; one that
# followed the agency's tiers follows them again. New bookings take it;
# bookings already made keep theirs.
class StartNextClientTermsVersion < AgencyCommand
  include ClientTermsCommandSupport

  COPIED_TIER = %w[min_days_before_departure charge_kind percentage amount_minor_units currency service_category].freeze
  COPIED_LINE = %w[description basis service_category amount_minor_units percentage currency due_rule days_before_departure due_on counts_as_acceptance position].freeze

  def initialize(agency:, actor:, departure:)
    @agency = agency
    @actor = actor
    @departure = departure
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      current = departure.client_terms_versions.lock.max_by(&:version_number)
      raise Error.new("Start the client terms first.", code: :invalid_state) if current.nil?
      raise Error.new("Version #{current.version_number} isn't locked yet; edit it instead.", code: :invalid_state) unless current.locked?

      version = departure.client_terms_versions.create!(
        agency: @agency, version_number: current.version_number + 1, agency_wording: current.agency_wording,
        departure_wording: current.departure_wording, overrides_cancellation_tiers: current.overrides_cancellation_tiers
      )
      current.own_cancellation_tiers.reject(&:copied_from_agency_default?).each do |tier|
        version.own_cancellation_tiers.create!(tier.attributes.slice(*COPIED_TIER).merge(agency: @agency))
      end
      current.schedule_lines.each { |line| version.schedule_lines.create!(line.attributes.slice(*COPIED_LINE).merge(agency: @agency)) }
      audit_departure!(departure, "departure.client_terms_created",
        { "client_terms_version_id" => version.id, "version_number" => version.version_number, "created" => true, "follows_version_id" => current.id })
      Result.new(status: :created, record: version)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
