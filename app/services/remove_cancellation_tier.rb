# Removes a client cancellation tier: an agency default, or one from a
# Departure's unlocked override.
class RemoveCancellationTier < AgencyCommand
  include ClientTermsCommandSupport

  def initialize(agency:, actor:, tier:, departure: nil, terms_version: nil)
    @agency = agency
    @actor = actor
    @tier = tier
    @departure = departure
    @terms_version = terms_version
  end

  def call
    if @terms_version
      ensure_departure_actor!(:manage_departures)
      ActiveRecord::Base.transaction do
        departure = lock_offering_context!
        version = lock_terms_version!(departure)
        tier = version.own_cancellation_tiers.lock.find(@tier.id)
        tier.destroy!
        audit_departure!(departure, "departure.client_cancellation_tier_removed", "tier_id" => tier.id, "client_terms_version_id" => version.id)
        Result.new(status: :updated, record: version)
      end
    else
      ensure_directory_actor!(@actor, @agency, :manage_agency_profile)
      ActiveRecord::Base.transaction do
        @agency.lock!
        tier = @agency.agency_cancellation_tiers.lock.find(@tier.id)
        tier.destroy!
        audit!(agency: @agency, action: "agency.cancellation_tier_removed", subject: @agency, actor: @actor, details: { "tier_id" => tier.id })
        Result.new(status: :updated, record: @agency)
      end
    end
  end
end
