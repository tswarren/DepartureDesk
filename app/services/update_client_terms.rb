# Edits an unlocked terms version's Departure wording and whether it
# overrides the agency cancellation tiers (BKG-28, BKG-31). Overriding
# starts from a copy of the agency's tiers; returning to the agency's
# tiers discards the override.
class UpdateClientTerms < AgencyCommand
  include ClientTermsCommandSupport

  def initialize(agency:, actor:, departure:, terms_version:, attributes:, lock_version:)
    @agency = agency
    @actor = actor
    @departure = departure
    @terms_version = terms_version
    @attributes = attributes.to_h.stringify_keys.slice("departure_wording", "overrides_cancellation_tiers")
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      version = lock_terms_version!(departure)
      ensure_version!(version)
      version.departure_wording = @attributes["departure_wording"] if @attributes.key?("departure_wording")
      if @attributes.key?("overrides_cancellation_tiers")
        version.overrides_cancellation_tiers = ActiveModel::Type::Boolean.new.cast(@attributes["overrides_cancellation_tiers"])
      end
      changed = version.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: version) if changed.empty?

      version.save!
      if version.saved_change_to_overrides_cancellation_tiers?
        version.own_cancellation_tiers.delete_all(:delete_all)
        if version.overrides_cancellation_tiers?
          @agency.agency_cancellation_tiers.each do |tier|
            version.own_cancellation_tiers.create!(tier.attributes.slice(*%w[min_days_before_departure charge_kind percentage amount_minor_units service_category]).merge(
              agency: @agency, currency: tier.currency && departure.operating_currency
            ))
          end
        end
      end
      audit_departure!(departure, "departure.client_terms_updated", "client_terms_version_id" => version.id, "changed" => changed.sort)
      Result.new(status: :updated, record: version)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
