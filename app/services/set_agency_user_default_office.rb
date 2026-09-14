class SetAgencyUserDefaultOffice < AgencyCommand
  def initialize(agency_user:, actor:, office:)
    @agency_user = agency_user
    @actor = actor
    @office = office
  end

  def call
    ActiveRecord::Base.transaction do
      @agency_user.agency.with_lock do
        @agency_user.lock!
        ensure_permitted!(@actor, :manage_agency_users)
        raise Error.new("Choose an office in this agency.", code: :invalid) if @office && @office.agency_id != @agency_user.agency_id

        @agency_user.update!(default_office: @office)
        audit!(agency: @agency_user.agency, action: "agency_user.default_office_changed", subject: @agency_user, actor: @actor, details: { "agency_user_id" => @agency_user.id, "office_id" => @office&.id })
      end
    end
    Result.new(status: :accepted, record: @agency_user)
  end
end
