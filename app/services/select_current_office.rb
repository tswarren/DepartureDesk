class SelectCurrentOffice < AgencyCommand
  def initialize(session:, office:)
    @session = session
    @office = office
  end

  def call
    user = @session.agency_user
    ensure_permitted!(user, :select_office_context)
    raise Error.new("Choose an active office in this agency.", code: :not_found) unless @office&.active? && @office.agency_id == user.agency_id

    @session.update!(office: @office)
    audit!(agency: user.agency, action: "session.office_selected", subject: @office, actor: user, details: { "office_id" => @office.id })
    Result.new(status: :accepted, record: @session)
  end
end
