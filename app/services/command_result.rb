class CommandResult
  attr_reader :status, :membership, :office, :assignment, :message

  def initialize(status:, membership: nil, office: nil, assignment: nil, message: nil)
    @status = status
    @membership = membership
    @office = office
    @assignment = assignment
    @message = message
  end

  def ok?
    %i[created replaced silent revoked accepted].include?(status)
  end

  def enqueue_mail?
    %i[created replaced].include?(status)
  end
end
