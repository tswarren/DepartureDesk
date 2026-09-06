class CommandResult
  attr_reader :status, :membership, :office, :assignment, :party, :message

  def initialize(status:, membership: nil, office: nil, assignment: nil, party: nil, message: nil)
    @status = status
    @membership = membership
    @office = office
    @assignment = assignment
    @party = party
    @message = message
  end

  def ok?
    %i[created replaced silent revoked accepted].include?(status)
  end

  def enqueue_mail?
    %i[created replaced].include?(status)
  end
end
