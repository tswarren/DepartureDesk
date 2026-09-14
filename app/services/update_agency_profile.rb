class UpdateAgencyProfile < AgencyCommand
  def initialize(agency:, actor:, name:, legal_name:, country_code:, default_currency:, default_timezone:, lock_version: nil)
    @agency = agency
    @actor = actor
    @name = name
    @legal_name = legal_name
    @country_code = country_code
    @default_currency = default_currency
    @default_timezone = default_timezone
    @lock_version = lock_version
  end

  def call
    ActiveRecord::Base.transaction do
      @agency.with_lock do
        @agency.reload
        ensure_permitted!(@actor, :manage_agency_profile)
        ensure_fresh_lock!
        ensure_active_agency!(@agency)
        @agency.update!(
          name: @name,
          legal_name: @legal_name,
          country_code: @country_code,
          default_currency: @default_currency,
          default_timezone: @default_timezone
        )
        audit!(agency: @agency, action: "agency.profile_updated", subject: @agency, actor: @actor, details: { "agency_id" => @agency.id })
      end
    end
    Result.new(status: :accepted, record: @agency)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def ensure_fresh_lock!
    return if @lock_version.nil?
    return if @agency.lock_version == @lock_version.to_i

    raise Error.new("This agency was updated by someone else.", code: :conflict)
  end
end
