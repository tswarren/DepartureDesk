class RecordAdministrativeAudit
  def self.record(agency:, action:, subject:, actor_agency_user: nil, actor_identifier: nil, details: {})
    new(agency:, action:, subject:, actor_agency_user:, actor_identifier:, details:).record
  end

  def initialize(agency:, action:, subject:, actor_agency_user:, actor_identifier:, details:)
    @agency = agency
    @action = action
    @subject = subject
    @actor_agency_user = actor_agency_user
    @actor_identifier = actor_identifier
    @details = details
  end

  def record
    ensure_subject_belongs_to_agency!
    AuditEvent.create!(
      agency: @agency,
      action: @action,
      actor_kind: @actor_agency_user ? "agency_user" : "system",
      actor_agency_user: @actor_agency_user,
      actor_identifier: @actor_agency_user ? nil : @actor_identifier,
      subject_type: @subject&.class&.name,
      subject_id: @subject&.id,
      details: @details
    )
  end

  private

  def ensure_subject_belongs_to_agency!
    return if @subject.nil?
    return if @subject.is_a?(Agency) && @subject.id == @agency.id
    return if @subject.is_a?(AgencyUser) && @subject.agency_id == @agency.id
    return if @subject.is_a?(Office) && @subject.agency_id == @agency.id
    return if @subject.is_a?(ClientPerson) && @subject.agency_id == @agency.id
    return if @subject.is_a?(Client) && @subject.agency_id == @agency.id
    return if @subject.is_a?(ClientOrganization) && @subject.agency_id == @agency.id
    return if @subject.is_a?(Supplier) && @subject.agency_id == @agency.id
    return if @subject.is_a?(SupplierLocation) && @subject.agency_id == @agency.id
    return if @subject.is_a?(SupplierContact) && @subject.agency_id == @agency.id
    return if @subject.is_a?(Departure) && @subject.agency_id == @agency.id
    return if @subject.is_a?(SupplierArrangement) && @subject.agency_id == @agency.id
    return if @subject.is_a?(SupplierReservation) && @subject.agency_id == @agency.id
    return if @subject.is_a?(ServiceOffer) && @subject.agency_id == @agency.id

    raise AgencyCommand::Error.new("Unknown audit subject type.", code: :invalid)
  end
end
