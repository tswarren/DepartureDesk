# Sets the agency's reusable client terms wording (BKG-28). A Departure's
# terms version copies it when the version is made.
class UpdateClientTermsDefaults < AgencyCommand
  def initialize(agency:, actor:, wording:, lock_version:)
    @agency = agency
    @actor = actor
    @wording = wording
    @lock_version = lock_version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_agency_profile)

    ActiveRecord::Base.transaction do
      agency = Agency.lock.find(@agency.id)
      raise Error.new("This record changed. Reload it and try again.", code: :conflict) if @lock_version.blank? || agency.lock_version != @lock_version.to_i

      agency.client_terms_wording = @wording
      return Result.new(status: :noop, record: agency) unless agency.client_terms_wording_changed?
      if agency.client_terms_wording.to_s.length > ClientTermsVersion::WORDING_LIMIT
        raise Error.new("Client terms wording is too long (#{ClientTermsVersion::WORDING_LIMIT} characters at most).", code: :invalid)
      end

      agency.save!
      audit!(agency:, action: "agency.client_terms_defaults_updated", subject: agency, actor: @actor,
        details: { "wording_length" => agency.client_terms_wording.to_s.length })
      Result.new(status: :updated, record: agency)
    end
  end
end
