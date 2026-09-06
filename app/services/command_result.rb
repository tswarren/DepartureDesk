class CommandResult
  attr_reader :status, :membership, :office, :assignment, :party, :message, :contact_point, :purpose_assignment, :relationship, :note

  def initialize(status:, membership: nil, office: nil, assignment: nil, party: nil, message: nil, contact_point: nil, purpose_assignment: nil, relationship: nil, note: nil)
    @status = status
    @membership = membership
    @office = office
    @assignment = assignment
    @party = party
    @message = message
    @contact_point = contact_point
    @purpose_assignment = purpose_assignment
    @relationship = relationship
    @note = note
  end

  def ok?
    %i[created replaced silent revoked accepted].include?(status)
  end

  def enqueue_mail?
    %i[created replaced].include?(status)
  end
end
