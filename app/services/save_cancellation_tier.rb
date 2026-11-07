# Adds or edits a client cancellation tier (BKG-31): one of the agency's
# defaults (Agency Admin), or one in a Departure's override (Departure
# management, while the version overrides and is unlocked).
class SaveCancellationTier < AgencyCommand
  include ClientTermsCommandSupport

  def initialize(agency:, actor:, attributes:, tier: nil, departure: nil, terms_version: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @attributes = clean(attributes, TIER_FIELDS)
    @tier = tier
    @departure = departure
    @terms_version = terms_version
    @lock_version = lock_version
  end

  def call
    @terms_version ? save_override! : save_default!
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("There is already a tier from that many days before departure.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def save_default!
    ensure_directory_actor!(@actor, @agency, :manage_agency_profile)
    ActiveRecord::Base.transaction do
      @agency.lock!
      tier = @tier ? @agency.agency_cancellation_tiers.lock.find(@tier.id).tap { |record| ensure_version!(record) } : @agency.agency_cancellation_tiers.new
      save_tier!(tier, @agency.default_currency) do |creating|
        audit!(agency: @agency, action: "agency.cancellation_tier_saved", subject: @agency, actor: @actor, details: tier_details(tier, creating))
      end
    end
  end

  def save_override!
    ensure_departure_actor!(:manage_departures)
    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      version = lock_terms_version!(departure)
      raise Error.new("Override the agency tiers before editing this departure's tiers.", code: :invalid_state) unless version.overrides_cancellation_tiers?

      tier = @tier ? version.own_cancellation_tiers.lock.find(@tier.id).tap { |record| ensure_version!(record) } : version.own_cancellation_tiers.new(agency: @agency)
      save_tier!(tier, departure.operating_currency) do |creating|
        audit_departure!(departure, "departure.client_cancellation_tier_saved", tier_details(tier, creating).merge("client_terms_version_id" => version.id))
      end
    end
  end

  def save_tier!(tier, currency)
    creating = tier.new_record?
    assign_tier!(tier, @attributes, currency)
    return Result.new(status: :noop, record: tier) if !creating && (tier.changed - %w[lock_version updated_at]).empty?

    tier.save!
    yield creating
    Result.new(status: creating ? :created : :updated, record: tier)
  end

  def tier_details(tier, creating)
    { "tier_id" => tier.id, "created" => creating, "min_days_before_departure" => tier.min_days_before_departure, "charge_kind" => tier.charge_kind }
  end
end
